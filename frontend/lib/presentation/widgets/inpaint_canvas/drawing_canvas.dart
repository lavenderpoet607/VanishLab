import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'drawing_controller.dart';

class DrawingCanvas extends StatefulWidget {
  final Uint8List imageBytes;
  final DrawingController controller;
  final Function(Size renderedSize) onSizeMeasured;

  const DrawingCanvas({
    super.key,
    required this.imageBytes,
    required this.controller,
    required this.onSizeMeasured,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final GlobalKey _imageKey = GlobalKey();

  void _checkRenderedSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _imageKey.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          widget.onSizeMeasured(renderBox.size);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _checkRenderedSize();

                    return Stack(
                      key: _imageKey,
                      alignment: Alignment.center,
                      children: [

                        Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                        ),

                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (details) {
                              widget.controller.startStroke(details.localPosition);
                            },
                            onPanUpdate: (details) {
                              widget.controller.addPoint(details.localPosition);
                            },
                            onPanEnd: (_) {
                              widget.controller.endStroke();
                            },
                            child: ListenableBuilder(
                              listenable: widget.controller,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: MaskPainter(
                                    items: widget.controller.items,
                                    previewColor: widget.controller.strokeColor,
                                    activeTool: widget.controller.activeTool,
                                    activeDragStart: widget.controller.activeDragStart,
                                    activeDragCurrent: widget.controller.activeDragCurrent,
                                    currentPoints: widget.controller.currentPoints,
                                  ),
                                  size: Size.infinite,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        _buildToolbar(context),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeTool = widget.controller.activeTool;

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildToolButton(
                            tool: InpaintTool.brush,
                            icon: Icons.brush,
                            label: 'Brush',
                            isSelected: activeTool == InpaintTool.brush,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: _buildToolButton(
                            tool: InpaintTool.box,
                            icon: Icons.crop_square_rounded,
                            label: 'Box',
                            isSelected: activeTool == InpaintTool.box,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: _buildToolButton(
                            tool: InpaintTool.lasso,
                            icon: Icons.gesture,
                            label: 'Lasso',
                            isSelected: activeTool == InpaintTool.lasso,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: _buildToolButton(
                            tool: InpaintTool.eraser,
                            icon: Icons.cleaning_services_outlined,
                            label: 'Erase',
                            isSelected: activeTool == InpaintTool.eraser,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      if (activeTool == InpaintTool.brush || activeTool == InpaintTool.eraser) ...[
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          child: Container(
                            width: (widget.controller.strokeWidth * 0.5).clamp(4.0, 18.0),
                            height: (widget.controller.strokeWidth * 0.5).clamp(4.0, 18.0),
                            decoration: BoxDecoration(
                              color: activeTool == InpaintTool.eraser ? Colors.white70 : AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.accent,
                              thumbColor: Colors.white,
                              overlayColor: AppTheme.accent.withValues(alpha: 0.2),
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: widget.controller.strokeWidth,
                              min: 8.0,
                              max: 70.0,
                              onChanged: (val) => widget.controller.setStrokeWidth(val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${widget.controller.strokeWidth.toInt()}px',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                activeTool == InpaintTool.box
                                    ? Icons.crop_square_rounded
                                    : Icons.gesture,
                                size: 14,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  activeTool == InpaintTool.box
                                      ? 'Tarik kotak pada watermark'
                                      : 'Gambar kurva melingkari watermark',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(width: 6),
                      Container(
                        height: 18,
                        width: 1,
                        color: AppTheme.border,
                      ),
                      const SizedBox(width: 2),

                      _buildActionIconButton(
                        icon: Icons.undo,
                        tooltip: 'Urungkan (Undo)',
                        isEnabled: widget.controller.canUndo,
                        onPressed: widget.controller.undo,
                      ),
                      const SizedBox(width: 2),
                      _buildActionIconButton(
                        icon: Icons.redo,
                        tooltip: 'Ulangi (Redo)',
                        isEnabled: widget.controller.canRedo,
                        onPressed: widget.controller.redo,
                      ),
                      const SizedBox(width: 2),
                      _buildActionIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Hapus Semua Mask',
                        isEnabled: widget.controller.hasStrokes,
                        color: widget.controller.hasStrokes ? AppTheme.error : AppTheme.textMuted,
                        onPressed: widget.controller.clear,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required InpaintTool tool,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.controller.setTool(tool),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 17),
      tooltip: tooltip,
      color: color ?? (isEnabled ? AppTheme.textPrimary : AppTheme.textMuted),
      onPressed: isEnabled ? onPressed : null,
    );
  }
}

class MaskPainter extends CustomPainter {
  final List<MaskItem> items;
  final Color previewColor;
  final InpaintTool activeTool;
  final Offset? activeDragStart;
  final Offset? activeDragCurrent;
  final List<Offset> currentPoints;

  MaskPainter({
    required this.items,
    required this.previewColor,
    required this.activeTool,
    this.activeDragStart,
    this.activeDragCurrent,
    required this.currentPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final defaultPaint = Paint()..color = previewColor;

    for (final item in items) {
      item.drawOnCanvas(
        canvas,
        paint: defaultPaint,
        scaleX: 1.0,
        scaleY: 1.0,
        isPreview: true,
      );
    }

    if (activeDragStart != null && activeDragCurrent != null) {
      if (activeTool == InpaintTool.box) {
        final rect = Rect.fromPoints(activeDragStart!, activeDragCurrent!);
        final fillPaint = Paint()
          ..color = previewColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = AppTheme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);

        final dotPaint = Paint()..color = Colors.white;
        canvas.drawCircle(rect.topLeft, 3, dotPaint);
        canvas.drawCircle(rect.topRight, 3, dotPaint);
        canvas.drawCircle(rect.bottomLeft, 3, dotPaint);
        canvas.drawCircle(rect.bottomRight, 3, dotPaint);
      } else if (activeTool == InpaintTool.lasso && currentPoints.length >= 2) {
        final path = Path();
        path.moveTo(currentPoints[0].dx, currentPoints[0].dy);
        for (int i = 1; i < currentPoints.length; i++) {
          path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
        }

        final linePaint = Paint()
          ..color = AppTheme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawPath(path, linePaint);

        final closingPaint = Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(currentPoints.last, currentPoints.first, closingPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MaskPainter oldDelegate) => true;
}
