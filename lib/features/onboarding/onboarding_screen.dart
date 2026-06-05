import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../core/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _notificationGranted = false;
  bool _storageGranted = false;
  bool _batteryIgnored = false;

  Timer? _tipTimer;
  int _currentTip = 0;
  final _proTips = [
    "Tip: You can queue multiple downloads at once.",
    "Tip: Share from YouTube, Insta, or X directly to Downloda.",
    "Tip: Long-press a downloaded item for quick actions."
  ];

  late List<OnboardingData> _pages;

  Color get _accentColor => context.colorAccent;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentTip = (_currentTip + 1) % _proTips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final storage = await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _notificationGranted = notif;
        _storageGranted = storage;
        _batteryIgnored = battery;
      });
    }
  }

  Widget _buildThemeSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildThemeCard('Light', ThemeMode.light),
        const SizedBox(width: 12),
        _buildThemeCard('System', ThemeMode.system),
        const SizedBox(width: 12),
        _buildThemeCard('Dark', ThemeMode.dark),
      ],
    );
  }

  Widget _buildThemeCard(String label, ThemeMode mode) {
    final settings = ref.watch(settingsProvider);
    final isSelected = settings.themeMode == (mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
    final color = _accentColor;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return GestureDetector(
      onTap: () {
        ref.read(settingsProvider.notifier).update(
          settings.copyWith(themeMode: mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system')
        );
      },
      child: AnimatedContainer(
        duration: 400.ms,
        width: 90,
        height: 140,
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? context.colorElevated : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Miniature Dashboard Preview
            Container(
              width: 46,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Positioned(top: 8, left: 8, right: 8, child: Container(height: 6, decoration: BoxDecoration(color: isSelected ? Colors.white : color, borderRadius: BorderRadius.circular(3)))),
                  Positioned(top: 20, left: 8, width: 20, child: Container(height: 4, decoration: BoxDecoration(color: (isSelected ? Colors.white : color).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  Positioned(bottom: 8, right: 8, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: isSelected ? Colors.white : color, shape: BoxShape.circle))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: context.typographyH3.copyWith(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : color),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNext() async {
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    } else {
      HapticFeedback.heavyImpact();
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setBool('onboarding_complete', true);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AppShell(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Future<void> _requestNotification() async {
    await Permission.notification.request();
    _checkPermissions();
  }

  Future<void> _requestStorage() async {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    } else {
      await Permission.storage.request();
    }
    _checkPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
    _checkPermissions();
  }

  Widget _buildPermissionItem(String title, IconData icon, bool isGranted, VoidCallback onTap) {
    final color = _accentColor;
    return AnimatedContainer(
      duration: 300.ms,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isGranted ? color.withValues(alpha: 0.1) : context.colorTextTertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? color.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? color : context.colorTextTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isGranted ? Colors.white : context.colorTextSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: context.typographyH3.copyWith(fontSize: 15),
            ),
          ),
          if (isGranted)
            Icon(Icons.check_circle_rounded, color: color, size: 24).animate().scale(duration: 400.ms, curve: Curves.easeOutBack)
          else
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.1),
                foregroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _pages = [
      OnboardingData(
        title: 'The "Invisible" Solution',
        subtitle: 'Stop the copy-paste fatigue. Share any link directly to Downloda and keep browsing. We handle the rest in the background, silently.',
        hero: Lottie.asset(
          'assets/lottie/jsons/socialMediaShare.json',
          width: 240, height: 240,
          errorBuilder: (c, e, s) => Icon(Icons.share_rounded, size: 80, color: _accentColor),
        ),
      ),
      OnboardingData(
        title: 'Choose Your Style',
        subtitle: 'Pick a look that suits your eyes. Your preference will be saved across sessions.',
        hero: _buildThemeSwitcher(),
        isThemePage: true,
      ),
      OnboardingData(
        title: 'Privacy by Default',
        subtitle: 'No data ever leaves your device for metadata extraction. Your downloads and history stay 100% on your device, encrypted by your OS.',
        hero: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/jsons/App Privacy.json',
              width: 200, height: 200,
              errorBuilder: (c, e, s) => Icon(Icons.security_rounded, size: 80, color: _accentColor),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: _accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text('Local-Only Verified', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      OnboardingData(
        title: 'Permissions & Access',
        subtitle: 'To provide a seamless experience, we need a few permissions to operate in the background and save your files.',
        hero: Column(
          children: [
            const _PermissionLottieCarousel(),
            const SizedBox(height: 16),
            _buildPermissionItem('Notifications', Icons.notifications_rounded, _notificationGranted, _requestNotification),
            _buildPermissionItem('Storage Access', Icons.folder_rounded, _storageGranted, _requestStorage),
          ],
        ),
        isPermissionPage: true,
      ),
      OnboardingData(
        title: 'Background Mastery',
        subtitle: 'To ensure large downloads aren\'t killed by the system, we strongly recommend disabling battery optimization for Downloda.',
        hero: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/jsons/batteryEffecient.json',
              width: 220, height: 220,
              errorBuilder: (c, e, s) => Icon(Icons.battery_charging_full_rounded, size: 80, color: _accentColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _batteryIgnored ? null : _requestBatteryOptimization,
              icon: Icon(_batteryIgnored ? Icons.check_circle_outline : Icons.battery_charging_full_rounded),
              label: Text(_batteryIgnored ? 'Optimization Disabled' : 'Open Battery Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _batteryIgnored ? context.colorBackground : _accentColor,
                foregroundColor: _batteryIgnored ? _accentColor : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
      OnboardingData(
        title: 'Zero Friction',
        subtitle: 'You\'re ready. Build your offline library without ever leaving your favorite apps.',
        hero: Lottie.asset(
          'assets/lottie/jsons/frictionFree.json',
          width: 240, height: 240,
          errorBuilder: (c, e, s) => Icon(Icons.rocket_launch_rounded, size: 80, color: _accentColor),
        ),
        isFinalPage: true,
      ),
    ];

    final currentColor = _accentColor;

    return Scaffold(
      backgroundColor: context.colorBackground,
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: 800.ms,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    currentColor.withValues(alpha: 0.15),
                    context.colorBackground,
                  ],
                ),
              ),
            ),
          ),

          // Progress Indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 32,
            right: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorTextTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step ${_currentPage + 1} of ${_pages.length}',
                    style: context.typographyBody.copyWith(
                      color: context.colorTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate(key: ValueKey('step_$_currentPage')).fadeIn().slideX(),
                
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: () {
                      _pageController.animateToPage(_pages.length - 1, duration: 600.ms, curve: Curves.easeOutCubic);
                    },
                    style: TextButton.styleFrom(foregroundColor: context.colorTextSecondary),
                    child: const Text('Skip'),
                  )
              ],
            ),
          ),

          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    page.hero
                      .animate(key: ValueKey('hero_$index'))
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 50),
                    
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: context.typographyH1.copyWith(fontSize: 28),
                    ).animate(key: ValueKey('title_$index')).fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      page.subtitle,
                      textAlign: TextAlign.center,
                      style: context.typographyBody.copyWith(
                        color: context.colorTextSecondary,
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ).animate(key: ValueKey('sub_$index')).fadeIn(delay: 400.ms).slideY(begin: 0.1),
                  ],
                ),
              );
            },
          ),

          // Bottom Controls & Pro Tips
          Positioned(
            bottom: 40,
            left: 32,
            right: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pro Tip Carousel
                if (_currentPage == _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: AnimatedSwitcher(
                      duration: 500.ms,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                          child: child,
                        ));
                      },
                      child: Container(
                        key: ValueKey<int>(_currentTip),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: currentColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: currentColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _proTips[_currentTip],
                                style: context.typographyBody.copyWith(color: context.colorTextSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(_pages.length, (i) => 
                        AnimatedContainer(
                          duration: 300.ms,
                          margin: const EdgeInsets.only(right: 8),
                          height: 6,
                          width: _currentPage == i ? 24 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? currentColor : context.colorTextTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )
                      ),
                    ),

                    GestureDetector(
                      onTap: _onNext,
                      child: AnimatedContainer(
                        duration: 300.ms,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: currentColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: currentColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                              style: context.typographyH3.copyWith(color: Colors.white),
                            ),
                            if (_currentPage < _pages.length - 1) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ]
                          ],
                        ),
                      ),
                    ).animate(target: _currentPage == _pages.length - 1 ? 1 : 0)
                     .shimmer(duration: 2.seconds, color: Colors.white24),
                  ],
                ),
              ],
            ).animate().fadeIn(delay: 800.ms),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final Widget hero;
  final bool isPermissionPage;
  final bool isThemePage;
  final bool isFinalPage;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.hero,
    this.isPermissionPage = false,
    this.isThemePage = false,
    this.isFinalPage = false,
  });
}

class _PermissionLottieCarousel extends StatefulWidget {
  const _PermissionLottieCarousel();

  @override
  State<_PermissionLottieCarousel> createState() => _PermissionLottieCarouselState();
}

class _PermissionLottieCarouselState extends State<_PermissionLottieCarousel> {
  int _currentIndex = 0;
  Timer? _timer;
  final List<String> _lotties = [
    'assets/lottie/jsons/notification.json',
    'assets/lottie/jsons/fileFolderPermission.json',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _lotties.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(_lotties.length, (index) {
          final isVisible = _currentIndex == index;
          return AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            child: AnimatedScale(
              scale: isVisible ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              child: Lottie.asset(
                _lotties[index],
                width: 160,
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Icon(Icons.error_outline, size: 60, color: Colors.white24),
              ),
            ),
          );
        }),
      ),
    );
  }
}
