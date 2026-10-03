import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum InpaintTool {
  brush,
  box,
  lasso,
  eraser,
}

abstract class MaskItem {
  final bool isEraser;
  MaskItem({this.isEraser = false});

  void drawOnCanvas(
    Canvas canvas, {
    required Paint paint,
    required double scaleX,
    required double scaleY,
    bool isPreview = false,
  });
}

class BrushStrokeItem extends MaskItem {
  final List<Offset> points;
  final double strokeWidth;

  BrushStrokeItem({
    required this.points,
    required this.strokeWidth,
    super.isEraser,
  });

  @override
  void drawOnCanvas(
    Canvas canvas, {
    required Paint paint,
    required double scaleX,
    required double scaleY,
    bool isPreview = false,
  }) {
    if (points.isEmpty) return;

    final p = Paint()
      ..color = isEraser ? const Color(0xFF000000) : paint.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = isPreview
          ? strokeWidth
          : strokeWidth * ((scaleX + scaleY) / 2);

    if (isEraser && isPreview) {
      p.blendMode = BlendMode.clear;
    }

    if (points.length == 1) {
      final pt = Offset(points[0].dx * scaleX, points[0].dy * scaleY);
      final dotPaint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;
      if (isEraser && isPreview) dotPaint.blendMode = BlendMode.clear;
      canvas.drawCircle(pt, p.strokeWidth / 2, dotPaint);
      return;
    }

    final path = Path();
    path.moveTo(points[0].dx * scaleX, points[0].dy * scaleY);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * scaleX, points[i].dy * scaleY);
    }
    canvas.drawPath(path, p);
  }
}

class BoxMaskItem extends MaskItem {
  final Rect rect;

  BoxMaskItem({
    required this.rect,
    super.isEraser,
  });

  @override
  void drawOnCanvas(
    Canvas canvas, {
    required Paint paint,
    required double scaleX,
    required double scaleY,
    bool isPreview = false,
  }) {
    final scaledRect = Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );

    final fillPaint = Paint()
      ..color = isEraser ? const Color(0xFF000000) : paint.color
      ..style = PaintingStyle.fill;

    if (isEraser && isPreview) {
      fillPaint.blendMode = BlendMode.clear;
    }

    canvas.drawRect(scaledRect, fillPaint);

    if (isPreview) {
      final borderPaint = Paint()
        ..color = isEraser ? Colors.white70 : paint.color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(scaledRect, borderPaint);
    }
  }
}

class LassoMaskItem extends MaskItem {
  final List<Offset> points;

  LassoMaskItem({
    required this.points,
    super.isEraser,
  });

  @override
  void drawOnCanvas(
    Canvas canvas, {
    required Paint paint,
    required double scaleX,
    required double scaleY,
    bool isPreview = false,
  }) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points[0].dx * scaleX, points[0].dy * scaleY);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * scaleX, points[i].dy * scaleY);
    }
    path.close();

    final fillPaint = Paint()
      ..color = isEraser ? const Color(0xFF000000) : paint.color
      ..style = PaintingStyle.fill;

    if (isEraser && isPreview) {
      fillPaint.blendMode = BlendMode.clear;
    }

    canvas.drawPath(path, fillPaint);

    if (isPreview) {
      final borderPaint = Paint()
        ..color = isEraser ? Colors.white70 : paint.color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, borderPaint);
    }
  }
}

class DrawingController extends ChangeNotifier {
  final List<MaskItem> _items = [];
  final List<MaskItem> _undoneItems = [];

  InpaintTool _activeTool = InpaintTool.brush;
  double _strokeWidth = 28.0;
  Color _strokeColor = const Color(0xAA06B6D4);

  Offset? _activeDragStart;
  Offset? _activeDragCurrent;
  final List<Offset> _currentPoints = [];

  InpaintTool get activeTool => _activeTool;
  double get strokeWidth => _strokeWidth;
  Color get strokeColor => _strokeColor;
  List<MaskItem> get items => List.unmodifiable(_items);

  Offset? get activeDragStart => _activeDragStart;
  Offset? get activeDragCurrent => _activeDragCurrent;
  List<Offset> get currentPoints => List.unmodifiable(_currentPoints);

  bool get canUndo => _items.isNotEmpty;
  bool get canRedo => _undoneItems.isNotEmpty;
  bool get hasStrokes => _items.isNotEmpty;

  void setTool(InpaintTool tool) {
    _activeTool = tool;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void setStrokeColor(Color color) {
    _strokeColor = color;
    notifyListeners();
  }

  void startStroke(Offset point) {
    _undoneItems.clear();
    _activeDragStart = point;
    _activeDragCurrent = point;
    _currentPoints.clear();
    _currentPoints.add(point);

    if (_activeTool == InpaintTool.brush || _activeTool == InpaintTool.eraser) {
      _items.add(BrushStrokeItem(
        points: [point],
        strokeWidth: _strokeWidth,
        isEraser: _activeTool == InpaintTool.eraser,
      ));
    }
    notifyListeners();
  }

  void addPoint(Offset point) {
    _activeDragCurrent = point;

    if (_activeTool == InpaintTool.brush || _activeTool == InpaintTool.eraser) {
      if (_items.isNotEmpty && _items.last is BrushStrokeItem) {
        (_items.last as BrushStrokeItem).points.add(point);
      }
    } else {
      _currentPoints.add(point);
    }
    notifyListeners();
  }

  void endStroke() {
    if (_activeDragStart != null && _activeDragCurrent != null) {
      if (_activeTool == InpaintTool.box) {
        final rect = Rect.fromPoints(_activeDragStart!, _activeDragCurrent!);
        if (rect.width.abs() > 3 && rect.height.abs() > 3) {
          _items.add(BoxMaskItem(rect: rect));
        }
      } else if (_activeTool == InpaintTool.lasso) {
        if (_currentPoints.length >= 3) {
          _items.add(LassoMaskItem(points: List.from(_currentPoints)));
        }
      }
    }

    _activeDragStart = null;
    _activeDragCurrent = null;
    _currentPoints.clear();
    notifyListeners();
  }

  void undo() {
    if (canUndo) {
      _undoneItems.add(_items.removeLast());
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _items.add(_undoneItems.removeLast());
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isNotEmpty) {
      _items.clear();
      _undoneItems.clear();
      _currentPoints.clear();
      _activeDragStart = null;
      _activeDragCurrent = null;
      notifyListeners();
    }
  }

  Future<Uint8List> generateBinaryMaskPng({
    required double originalWidth,
    required double originalHeight,
    required Size renderedSize,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, originalWidth, originalHeight),
    );

    final bgPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, originalWidth, originalHeight), bgPaint);

    final scaleX = originalWidth / (renderedSize.width > 0 ? renderedSize.width : originalWidth);
    final scaleY = originalHeight / (renderedSize.height > 0 ? renderedSize.height : originalHeight);

    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);

    for (final item in _items) {
      item.drawOnCanvas(
        canvas,
        paint: whitePaint,
        scaleX: scaleX,
        scaleY: scaleY,
        isPreview: false,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(originalWidth.toInt(), originalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode binary mask PNG.');
    }

    return byteData.buffer.asUint8List();
  }
}
