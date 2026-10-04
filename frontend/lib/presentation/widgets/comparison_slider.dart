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
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                resolvedAfter,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
                left: (width * _splitRatio) - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),

              Positioned(
                left: (width * _splitRatio) - 18,
                top: (height / 2) - 18,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _splitRatio = (_splitRatio + (details.delta.dx / width)).clamp(0.02, 0.98);
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left_rounded, size: 16, color: Colors.white),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 14,
                top: 14,
                child: _buildBadge('ORIGINAL', const Color(0xCC090A0E)),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _buildBadge('CLEANED', AppTheme.accent.withValues(alpha: 0.9)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusTag),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.8,
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
