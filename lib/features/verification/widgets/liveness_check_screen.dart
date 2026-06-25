import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/widgets.dart';

enum _LivenessStep { centerFace, blink, turnHead, done }

/// On-device liveliness gate run immediately before the verification selfie.
/// Walks the user through "center your face" -> "blink" -> "turn your head"
/// using ML Kit face detection on the live camera stream, purely to block a
/// static printed/screen photo from being submitted as a selfie. This is not
/// a biometric match or anti-spoof guarantee — final acceptance is always
/// the manual review on the other end, this just gates capture.
///
/// Pops with the captured selfie [File] once every step passes, or `null`
/// if the user backs out.
class LivenessCheckScreen extends StatefulWidget {
  const LivenessCheckScreen({super.key});

  @override
  State<LivenessCheckScreen> createState() => _LivenessCheckScreenState();
}

class _LivenessCheckScreenState extends State<LivenessCheckScreen> {
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  CameraController? _controller;
  _LivenessStep _step = _LivenessStep.centerFace;
  String? _error;
  bool _busy = false;
  bool _isDetecting = false;

  double? _blinkBaselineEyeOpen;
  bool _sawEyesClosed = false;
  double? _turnBaselineAngleY;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the camera: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isDetecting || _busy || _step == _LivenessStep.done) return;
    _isDetecting = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) return;
      _evaluate(faces.first);
    } catch (_) {
      // Drop the frame — the next one will retry.
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final rotation =
        InputImageRotationValue.fromRawValue(controller.description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _evaluate(Face face) {
    switch (_step) {
      case _LivenessStep.centerFace:
        // Just require a confidently-detected, roughly front-facing face.
        final yaw = face.headEulerAngleY ?? 0;
        final pitch = face.headEulerAngleX ?? 0;
        if (yaw.abs() < 10 && pitch.abs() < 10) {
          _turnBaselineAngleY = yaw;
          _advance(_LivenessStep.blink);
        }
        break;
      case _LivenessStep.blink:
        final leftOpen = face.leftEyeOpenProbability;
        final rightOpen = face.rightEyeOpenProbability;
        if (leftOpen == null || rightOpen == null) return;
        final eyeOpen = (leftOpen + rightOpen) / 2;
        _blinkBaselineEyeOpen ??= eyeOpen;
        if (!_sawEyesClosed && eyeOpen < 0.3) {
          _sawEyesClosed = true;
        } else if (_sawEyesClosed && eyeOpen > 0.7) {
          _advance(_LivenessStep.turnHead);
        }
        break;
      case _LivenessStep.turnHead:
        final yaw = face.headEulerAngleY ?? 0;
        final baseline = _turnBaselineAngleY ?? 0;
        if ((yaw - baseline).abs() > 15) {
          _advance(_LivenessStep.done);
          _capture();
        }
        break;
      case _LivenessStep.done:
        break;
    }
  }

  void _advance(_LivenessStep next) {
    if (!mounted || _step == next) return;
    setState(() => _step = next);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      await controller.stopImageStream();
      final picture = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(picture.path));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not capture the selfie: $e';
        _busy = false;
        _step = _LivenessStep.centerFace;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  String get _instruction => switch (_step) {
        _LivenessStep.centerFace => 'Center your face in the frame and look straight ahead.',
        _LivenessStep.blink => 'Now blink naturally.',
        _LivenessStep.turnHead => 'Slowly turn your head to one side.',
        _LivenessStep.done => 'Got it — capturing your selfie...',
      };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Liveliness check'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: controller == null || !controller.value.isInitialized
                    ? (_error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: ErrorBanner(message: _error!),
                          )
                        : const LoadingIndicator())
                    : ClipOval(
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: CameraPreview(controller),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _instruction,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
              ),
            ),
            if (_error != null && controller != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ErrorBanner(message: _error!),
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final reached = _step.index > i;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 28,
                    height: 4,
                    decoration: BoxDecoration(
                      color: reached ? AppColors.secondary : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
