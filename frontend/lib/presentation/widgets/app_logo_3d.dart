import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppLogoSize {
  small(32, 8, 14),
  standard(72, 16, 28),
  large(112, 24, 44);

  final double dimension;
  final double borderRadius;
  final double iconSize;

  const AppLogoSize(this.dimension, this.borderRadius, this.iconSize);
}

class AppLogo3D extends StatefulWidget {
  final AppLogoSize size;
  final bool enableFloatingAnimation;
  final bool showGlow;
  final VoidCallback? onTap;

  const AppLogo3D({
    super.key,
    this.size = AppLogoSize.standard,
    this.enableFloatingAnimation = false,
    this.showGlow = true,
    this.onTap,
  });

  @override
  State<AppLogo3D> createState() => _AppLogo3DState();
}

class _AppLogo3DState extends State<AppLogo3D> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _tiltAnimation = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.enableFloatingAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AppLogo3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableFloatingAnimation != oldWidget.enableFloatingAnimation) {
      if (widget.enableFloatingAnimation) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = widget.size.dimension;
    final radius = widget.size.borderRadius;

    Widget logoContent = Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: widget.showGlow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: dim * 0.35,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.22),
                  blurRadius: dim * 0.25,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/logo_3d.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackVector(dim, radius),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.enableFloatingAnimation) {
      return AnimatedBuilder(
        animation: _tiltAnimation,
        builder: (context, child) {
          final tilt = _tiltAnimation.value;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateY(tilt)
            ..rotateX(tilt * 0.7);

          return Transform.translate(
            offset: Offset(
              0.0,
              math.sin(_controller.value * 2 * math.pi) * 3.5,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: logoContent,
        ),
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: logoContent,
      );
    }

    return logoContent;
  }

  Widget _buildFallbackVector(double dim, double radius) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 1.1,
          colors: [
            Color(0xFF222836),
            Color(0xFF0F1218),
          ],
        ),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFF884D), AppTheme.accent],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Icon(
            Icons.auto_fix_high,
            size: widget.size.iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
