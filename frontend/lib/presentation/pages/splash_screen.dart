import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/backend_launcher_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_logo_3d.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _progressAnimation;

  String _statusMessage = 'Memuat modul AI deep learning...';

  @override
  void initState() {
    super.initState();

    BackendLauncherService.ensureBackendRunning();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.08, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoRotation = Tween<double>(begin: -math.pi * 0.75, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.40, 0.68, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.40, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.20, 0.95, curve: Curves.easeInOut),
      ),
    );

    _animController.addListener(() {
      final p = _progressAnimation.value;
      String nextStatus;
      if (p < 0.35) {
        nextStatus = 'Memuat modul AI deep learning...';
      } else if (p < 0.70) {
        nextStatus = 'Menyiapkan mesin inpainting & downloader...';
      } else if (p < 0.95) {
        nextStatus = 'Memeriksa kuota & konektivitas cloud...';
      } else {
        nextStatus = 'Siap digunakan!';
      }

      if (nextStatus != _statusMessage) {
        setState(() {
          _statusMessage = nextStatus;
        });
      }
    });

    _animController.forward().then((_) => _navigateToNextScreen());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final storage = sl<StorageService>();
    final hasSeenOnboarding = storage.hasSeenOnboarding();

    final nextScreen = hasSeenOnboarding
        ? const MainNavigationScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => nextScreen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: size.height * 0.16,
            left: size.width * 0.5 - 160,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.15),
                    AppTheme.accent.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    final rotY = _logoRotation.value;
                    final scale = _logoScale.value;
                    final opacity = _logoOpacity.value;

                    final transform = Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateY(rotY)
                      ..rotateX(rotY * 0.28);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: transform,
                          child: const AppLogo3D(
                            size: AppLogoSize.large,
                            enableFloatingAnimation: false,
                            showGlow: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _textOpacity,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFFFF2EB),
                                  Color(0xFFFF7A33),
                                ],
                                stops: [0.0, 0.7, 1.0],
                              ).createShader(bounds),
                              child: const Text(
                                'VanishLab',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'AI Watermark Remover & Clean Media',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceCard,
                                borderRadius: BorderRadius.circular(AppTheme.radiusTag),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: const Text(
                                'v1.2.0 • Ultra HD Clean Engine',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, _) {
                          final value = _progressAnimation.value;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusTag),
                            child: SizedBox(
                              height: 4,
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: AppTheme.surfaceRaised,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
