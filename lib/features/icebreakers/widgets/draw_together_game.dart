import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/ice_breaker_session.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/icebreaker_content.dart';

/// "Draw Together": a shared canvas where each stroke is appended to
/// `state['strokes']` (normalized 0..1 points so it renders consistently on
/// any screen size) and synced via realtime.
class DrawTogetherGame extends ConsumerStatefulWidget {
  const DrawTogetherGame({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.otherUserId,
  });

  final IceBreakerSession session;
  final String currentUserId;
  final String otherUserId;

  @override
  ConsumerState<DrawTogetherGame> createState() => _DrawTogetherGameState();
}

class _DrawTogetherGameState extends ConsumerState<DrawTogetherGame> {
  final List<Offset> _currentStroke = [];
  bool _isUpdating = false;
  String? _error;

  String get _myColor =>
      widget.currentUserId.compareTo(widget.otherUserId) < 0
          ? IcebreakerContent.colorA
          : IcebreakerContent.colorB;

  /// Normalizes `state['strokes']` defensively — same RLS-has-no-shape-check
  /// caveat as `PromptsGame._qa` (see CLAUDE.md); drop non-Map entries so a
  /// malformed write from either client doesn't crash the whole canvas.
  List<Map<String, dynamic>> get _strokes =>
      (widget.session.state['strokes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final local = details.localPosition;
    setState(() {
      _currentStroke.add(Offset(local.dx / size.width, local.dy / size.height));
    });
  }

  Future<void> _onPanEnd() async {
    if (_currentStroke.length < 2) {
      setState(() => _currentStroke.clear());
      return;
    }
    final strokes = _strokes;
    strokes.add({
      'color': _myColor,
      'points': _currentStroke.map((p) => [p.dx, p.dy]).toList(),
    });
    setState(() => _currentStroke.clear());
    await _save(strokes);
  }

  Future<void> _clear() async {
    await _save([]);
  }

  Future<void> _save(List<Map<String, dynamic>> strokes) async {
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).updateState(widget.session.id, {'strokes': strokes});
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Doodle something together — take turns adding to the canvas.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  onPanStart: (details) =>
                      setState(() => _currentStroke
                        ..clear()
                        ..add(Offset(details.localPosition.dx / size.width,
                            details.localPosition.dy / size.height))),
                  onPanUpdate: (details) => _onPanUpdate(details, size),
                  onPanEnd: (_) => _onPanEnd(),
                  child: CustomPaint(
                    size: size,
                    painter: _DrawingPainter(
                      strokes: _strokes,
                      liveStroke: _currentStroke,
                      liveColor: _myColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        PearmoButton(
          label: 'Clear canvas',
          variant: PearmoButtonVariant.outline,
          icon: Icons.delete_outline,
          isLoading: _isUpdating,
          onPressed: _isUpdating ? null : _clear,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
      ],
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.strokes, required this.liveStroke, required this.liveColor});

  final List<Map<String, dynamic>> strokes;
  final List<Offset> liveStroke;
  final String liveColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      // Points are written as [num, num] but nothing enforces that shape
      // server-side — skip a malformed stroke rather than crashing the
      // whole canvas render.
      try {
        final rawPoints = stroke['points'];
        if (rawPoints is! List) continue;
        final points = rawPoints
            .whereType<List>()
            .where((p) => p.length >= 2)
            .map((p) => Offset(
                  (p[0] as num).toDouble() * size.width,
                  (p[1] as num).toDouble() * size.height,
                ))
            .toList();
        if (points.length < 2) continue;
        final color = _parseColor(stroke['color'] as String? ?? IcebreakerContent.colorA);
        _drawPath(canvas, points, color);
      } catch (_) {
        continue;
      }
    }

    if (liveStroke.length > 1) {
      final points =
          liveStroke.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      _drawPath(canvas, points, _parseColor(liveColor));
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  Color _parseColor(String hex) {
    final value = int.parse(hex.replaceFirst('#', 'FF'), radix: 16);
    return Color(value);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.liveStroke != liveStroke;
}
