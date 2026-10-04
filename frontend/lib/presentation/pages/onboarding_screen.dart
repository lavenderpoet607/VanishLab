import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_logo_3d.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingFeatureBadge {
  final IconData icon;
  final String label;

  const _OnboardingFeatureBadge(this.icon, this.label);
}

class _OnboardingItem {
  final String tag;
  final String title;
  final String description;
  final String imagePath;
  final List<_OnboardingFeatureBadge> badges;

  const _OnboardingItem({
    required this.tag,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.badges,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      tag: 'AI INPAINTING ENGINE',
      title: 'Hapus Watermark Sekejap',
      description:
          'Hilangkan logo, teks berjalan, atau objek yang mengganggu pada foto & video dengan AI generative inpainting yang menyatu mulus ke latar belakang.',
      imagePath: 'assets/images/onboarding_inpaint.jpg',
      badges: [
        _OnboardingFeatureBadge(Icons.brush_outlined, 'Brush & Custom Box'),
        _OnboardingFeatureBadge(Icons.auto_awesome_outlined, 'Generative Fill'),
        _OnboardingFeatureBadge(Icons.blur_off_outlined, 'Zero Blur Distortion'),
      ],
    ),
    _OnboardingItem(
      tag: 'CLEAN MEDIA DOWNLOADER',
      title: 'Unduh Media Tanpa Watermark',
      description:
          'Ekstraksi instan dari TikTok, Instagram Reels, YouTube Shorts, dan Twitter/X. Simpan video HD jernih atau konversi langsung ke audio MP3 320kbps.',
      imagePath: 'assets/images/onboarding_download.jpg',
      badges: [
        _OnboardingFeatureBadge(Icons.devices_outlined, 'Multi-Platform'),
        _OnboardingFeatureBadge(Icons.audiotrack_outlined, 'Ekstrak Audio MP3'),
        _OnboardingFeatureBadge(Icons.crop_outlined, 'Auto-Crop Bars'),
      ],
    ),
    _OnboardingItem(
      tag: 'HIGH-PERFORMANCE ENGINE',
      title: 'Kualitas 60 FPS & Suara Utuh',
      description:
          'Pemrosesan video terdistribusi menjaga frame rate 60 FPS dan kualitas audio asli 100% tanpa kompresi pecah. Nikmati 50 kuota gratis setiap hari.',
      imagePath: 'assets/images/logo_3d.jpg',
      badges: [
        _OnboardingFeatureBadge(Icons.speed_outlined, '60 FPS Lossless'),
        _OnboardingFeatureBadge(Icons.lock_clock_outlined, '24 Jam Auto-Purge'),
        _OnboardingFeatureBadge(Icons.card_giftcard_outlined, '50 Kuota Gratis/Hari'),
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final storage = sl<StorageService>();
    await storage.setHasSeenOnboarding(true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onNext() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppLogo3D(size: AppLogoSize.small, showGlow: false),
                          const SizedBox(width: 8),
                          Text(
                            'VanishLab',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
                      if (!isLastPage)
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('Lewati'),
                        )
                      else
                        const SizedBox(width: 48, height: 32),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildPageItem(item);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _items.length,
                          (index) => _buildIndicator(index == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage ? 'Mulai Sekarang' : 'Lanjut',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? Icons.arrow_forward_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                size: isLastPage ? 18 : 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(right: 8),
      height: 4,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.accent : AppTheme.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPageItem(_OnboardingItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final imageSize = (availableHeight * 0.40).clamp(160.0, 260.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: availableHeight * 0.02),
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        item.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return Container(
                            color: AppTheme.surfaceCard,
                            child: const Icon(
                              Icons.auto_fix_high,
                              size: 56,
                              color: AppTheme.accent,
                            ),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: availableHeight * 0.035),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTag),
                  border: Border.all(
                    color: AppTheme.border,
                  ),
                ),
                child: Text(
                  item.tag,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: item.badges.map((badge) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badge.icon, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          badge.label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: availableHeight * 0.03),
            ],
          ),
        );
      },
    );
  }
}
