import 'package:flutter/gestures.dart' show DragStartBehavior;
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
  /// Brand-palette swatches, stored as the same '#RRGGBB' hex strings
  /// strokes already use — free choice, not locked to one color per player.
  static const List<String> _palette = [
    IcebreakerContent.colorA,
    IcebreakerContent.colorB,
    '#2D2A32',
    '#E5604D',
    '#4A90D9',
    '#4CAF82',
    '#B8A9F3',
    '#FFD166',
  ];

  static const List<double> _strokeWidths = [2, 4, 7];

  final List<Offset> _currentStroke = [];
  bool _isUpdating = false;
  String? _error;

  late String _selectedColor = _defaultColor;
  double _selectedWidth = 4;

  /// Default starting color per player (same rule as before — deterministic
  /// so the two players start out visually distinguishable), now just the
  /// initial pick rather than a fixed assignment.
  String get _defaultColor =>
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
      _currentStroke.add(Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      ));
    });
  }

  Future<void> _onPanEnd() async {
    if (_currentStroke.length < 2) {
      setState(() => _currentStroke.clear());
      return;
    }
    final strokes = _strokes;
    strokes.add({
      'color': _selectedColor,
      'width': _selectedWidth,
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
    // Deliberately a plain Column, NOT a ListView/scrollable — the canvas's
    // pan gestures used to compete with a scroll gesture recognizer in the
    // same gesture arena, which is what caused the reported "screen shakes
    // and doesn't draw correctly" bug. With nothing scrollable wrapping it,
    // the pan recognizer is the only one in play.
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Doodle something together, taking turns adding to the canvas.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          _Toolbar(
            palette: _palette,
            selectedColor: _selectedColor,
            onColorSelected: (c) => setState(() => _selectedColor = c),
            strokeWidths: _strokeWidths,
            selectedWidth: _selectedWidth,
            onWidthSelected: (w) => setState(() => _selectedWidth = w),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AspectRatio(
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
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (details) =>
                          setState(() => _currentStroke
                            ..clear()
                            ..add(Offset(
                              (details.localPosition.dx / size.width).clamp(0.0, 1.0),
                              (details.localPosition.dy / size.height).clamp(0.0, 1.0),
                            ))),
                      onPanUpdate: (details) => _onPanUpdate(details, size),
                      onPanEnd: (_) => _onPanEnd(),
                      child: CustomPaint(
                        size: size,
                        painter: _DrawingPainter(
                          strokes: _strokes,
                          liveStroke: _currentStroke,
                          liveColor: _selectedColor,
                          liveWidth: _selectedWidth,
                        ),
                      ),
                    ),
                  );
                },
              ),
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
      ),
    );
  }
}

/// Color swatches + stroke-width picker, in one compact row each.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.palette,
    required this.selectedColor,
    required this.onColorSelected,
    required this.strokeWidths,
    required this.selectedWidth,
    required this.onWidthSelected,
  });

  final List<String> palette;
  final String selectedColor;
  final ValueChanged<String> onColorSelected;
  final List<double> strokeWidths;
  final double selectedWidth;
  final ValueChanged<double> onWidthSelected;

  static Color _parseColor(String hex) => Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: palette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final hex = palette[index];
                final isSelected = hex == selectedColor;
                return GestureDetector(
                  onTap: () => onColorSelected(hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _parseColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.textPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final w in strokeWidths)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => onWidthSelected(w),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: w == selectedWidth ? AppColors.primaryLight : AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: w == selectedWidth ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: w * 1.6,
                        height: w * 1.6,
                        decoration: const BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({
    required this.strokes,
    required this.liveStroke,
    required this.liveColor,
    required this.liveWidth,
  });

  final List<Map<String, dynamic>> strokes;
  final List<Offset> liveStroke;
  final String liveColor;
  final double liveWidth;

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
        final width = (stroke['width'] as num?)?.toDouble() ?? 4.0;
        _drawPath(canvas, points, color, width);
      } catch (_) {
        continue;
      }
    }

    if (liveStroke.length > 1) {
      final points =
          liveStroke.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      _drawPath(canvas, points, _parseColor(liveColor), liveWidth);
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
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
