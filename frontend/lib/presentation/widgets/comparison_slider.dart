import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';

class BeforeAfterComparison extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;

  const BeforeAfterComparison({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
  });

  @override
  State<BeforeAfterComparison> createState() => _BeforeAfterComparisonState();
}

class _BeforeAfterComparisonState extends State<BeforeAfterComparison> {
  double _splitRatio = 0.5;

  @override
  Widget build(BuildContext context) {
    final resolvedAfter = ApiConfig.resolveForNetwork(widget.afterImageUrl);
    final resolvedBefore = ApiConfig.resolveForNetwork(widget.beforeImageUrl);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                resolvedAfter,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, color: AppTheme.error, size: 36),
                      SizedBox(height: 8),
                      Text('Failed to load result image', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              ClipRect(
                clipper: _HorizontalClipper(_splitRatio),
                child: Image.network(
                  resolvedBefore,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, color: AppTheme.error, size: 36),
                        SizedBox(height: 8),
                        Text('Failed to load original image', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: (width * _splitRatio) - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),

              Positioned(
                left: (width * _splitRatio) - 20,
                top: (height / 2) - 20,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _splitRatio = (_splitRatio + (details.delta.dx / width)).clamp(0.02, 0.98);
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left, size: 18, color: Colors.black),
                        Icon(Icons.chevron_right, size: 18, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 16,
                top: 16,
                child: _buildBadge('ORIGINAL', Colors.black54),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: _buildBadge('CLEANED', AppTheme.primary.withValues(alpha: 0.8)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  final double ratio;

  _HorizontalClipper(this.ratio);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * ratio, size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalClipper oldClipper) => oldClipper.ratio != ratio;
}
