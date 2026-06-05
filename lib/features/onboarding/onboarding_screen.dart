import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  late final AnimationController _shakeController;

  bool get _isCurrentPageActionCompleted {
    if (_currentPage == 3) {
      return _notificationGranted && _storageGranted;
    }
    if (_currentPage == 4) {
      return _batteryIgnored;
    }
    return true;
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
    HapticFeedback.heavyImpact();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _shakeController.dispose();
    _pageController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
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

  Widget _buildThemeToggler() {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.themeMode == 'dark';
    final accent = context.colorAccent;
    final bg = context.colorElevated;

    return Container(
      width: 180,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          // Sliding Capsule
          AnimatedAlign(
            duration: 250.ms,
            curve: Curves.easeInOut,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 90,
              height: 44,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
            ),
          ),
          
          // Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(settingsProvider.notifier).update(
                      settings.copyWith(themeMode: 'light')
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Light',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? context.colorTextSecondary : context.colorBackground,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(settingsProvider.notifier).update(
                      settings.copyWith(themeMode: 'dark')
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Dark',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? context.colorBackground : context.colorTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onNext() async {
    if (!_isCurrentPageActionCompleted) {
      _triggerShake();
      if (_currentPage == 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please grant all required permissions to continue'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: context.colorFailure,
          ),
        );
        if (!_notificationGranted) {
          await _requestNotification();
        } else if (!_storageGranted) {
          await _requestStorage();
        }
      } else if (_currentPage == 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please disable battery optimization to continue'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: context.colorFailure,
          ),
        );
        if (!_batteryIgnored) {
          await _requestBatteryOptimization();
        }
      }
      return;
    }

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

  Widget _buildCompactPermissionItem(String label, IconData icon, bool isGranted, VoidCallback onTap) {
    final accent = context.colorAccent;
    final lightBg = isGranted ? accent.withValues(alpha: 0.1) : context.colorElevated;
    
    final item = GestureDetector(
      onTap: isGranted ? null : onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted ? accent.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isGranted ? accent : accent.withValues(alpha: 0.6),
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isGranted ? accent : accent.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGranted) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, color: accent, size: 14),
            ],
          ],
        ),
      ),
    );

    if (isGranted) {
      return Expanded(child: item);
    } else {
      return Expanded(
        child: item
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.45)),
      );
    }
  }

  Widget _buildBatteryButton() {
    final accent = context.colorAccent;
    if (_batteryIgnored) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: accent, size: 16),
            const SizedBox(width: 8),
            Text(
              'Optimization Disabled',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _requestBatteryOptimization,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: context.colorElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_charging_full_rounded, color: accent, size: 16),
            const SizedBox(width: 8),
            Text(
              'Open Battery Settings',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.45));
  }

  @override
  Widget build(BuildContext context) {
    _pages = [
      OnboardingData(
        title: 'The "Invisible" Solution',
        subtitle: 'Stop the copy-paste fatigue. Share any link directly to Downloda and keep browsing. We handle the rest in the background, silently.',
        hero: Image.asset(
          'assets/lottie/gifs/Download.gif',
          width: 300, height: 300,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.share_rounded, size: 80, color: context.colorAccent),
        ),
      ),
      OnboardingData(
        title: 'Choose Your Style',
        subtitle: 'Pick a look that suits your eyes. Your preference will be saved across sessions.',
        hero: Image.asset(
          'assets/lottie/gifs/theme_toggle.gif',
          width: 240, height: 240,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.palette_rounded, size: 60, color: context.colorAccent),
        ),
        isThemePage: true,
      ),
      OnboardingData(
        title: 'Privacy by Default',
        subtitle: 'No data ever leaves your device for metadata extraction. Your downloads and history stay 100% on your device, encrypted by your OS.',
        hero: Image.asset(
          'assets/lottie/gifs/secure_privacy.gif',
          width: 270, height: 270,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.security_rounded, size: 80, color: context.colorAccent),
        ),
      ),
      OnboardingData(
        title: 'Permissions & Access',
        subtitle: 'To provide a seamless experience, we need a few permissions to operate in the background and save your files.',
        hero: Image.asset(
          'assets/lottie/gifs/notifications.gif',
          width: 240, height: 240,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.notifications_rounded, size: 80, color: context.colorAccent),
        ),
        isPermissionPage: true,
      ),
      OnboardingData(
        title: 'Background Mastery',
        subtitle: 'To ensure large downloads aren\'t killed by the system, we strongly recommend disabling battery optimization for Downloda.',
        hero: Image.asset(
          'assets/lottie/gifs/Lowbattery.gif',
          width: 260, height: 260,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.battery_charging_full_rounded, size: 80, color: context.colorAccent),
        ),
        isBatteryPage: true,
      ),
      OnboardingData(
        title: 'Zero Friction',
        subtitle: 'You\'re ready. Build your offline library without ever leaving your favorite apps.',
        hero: Image.asset(
          'assets/lottie/gifs/friction_free.gif',
          width: 300, height: 300,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.rocket_launch_rounded, size: 80, color: context.colorAccent),
        ),
        isFinalPage: true,
      ),
    ];

    final isDark = context.isDarkMode;
    final currentColor = context.colorAccent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.colorBackground,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.colorBackground,
        body: Stack(
          children: [
            // Progress Indicator / Top header
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colorAccent.withValues(alpha: 0.08),
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
                final topPadding = MediaQuery.of(context).padding.top + 64;
  
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(height: topPadding),
                        SizedBox(
                          height: 310,
                          child: Center(
                            child: page.hero
                              .animate(key: ValueKey('hero_$index'))
                              .fadeIn(duration: 600.ms)
                              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: context.typographyH1.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: context.colorTextPrimary,
                          ),
                        ).animate(key: ValueKey('title_$index')).fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: context.typographyBody.copyWith(
                            color: context.colorTextSecondary,
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ).animate(key: ValueKey('sub_$index')).fadeIn(delay: 400.ms).slideY(begin: 0.1),
                        
                        // Interactive controls positioned below description text:
                        if (page.isThemePage) ...[
                          const SizedBox(height: 24),
                          _buildThemeToggler()
                            .animate(key: ValueKey('theme_toggle_$index'))
                            .fadeIn(delay: 500.ms)
                            .slideY(begin: 0.2),
                        ] else if (page.isPermissionPage) ...[
                          const SizedBox(height: 24),
                          Animate(
                            controller: _shakeController,
                            autoPlay: false,
                            effects: const [
                              ShakeEffect(hz: 8, curve: Curves.easeInOut),
                            ],
                            child: Row(
                              children: [
                                _buildCompactPermissionItem('Notifications', Icons.notifications_rounded, _notificationGranted, _requestNotification),
                                const SizedBox(width: 12),
                                _buildCompactPermissionItem('Storage Access', Icons.folder_rounded, _storageGranted, _requestStorage),
                              ],
                            ),
                          ).animate(key: ValueKey('permission_row_$index'))
                           .fadeIn(delay: 500.ms)
                           .slideY(begin: 0.2),
                        ] else if (page.isBatteryPage) ...[
                          const SizedBox(height: 24),
                          Animate(
                            controller: _shakeController,
                            autoPlay: false,
                            effects: const [
                              ShakeEffect(hz: 8, curve: Curves.easeInOut),
                            ],
                            child: _buildBatteryButton(),
                          ).animate(key: ValueKey('battery_button_$index'))
                           .fadeIn(delay: 500.ms)
                           .slideY(begin: 0.2),
                        ],
                        
                        SizedBox(height: 160 + MediaQuery.of(context).padding.bottom), // Space for bottom controls
                      ],
                    ),
                  ),
                );
              },
            ),
  
            // Bottom Controls & Pro Tips
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 32,
              right: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pro Tip Carousel (only shown on the last page)
                  if (_currentPage == _pages.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: AnimatedSwitcher(
                        duration: 500.ms,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          );
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
  
                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => 
                      AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 6),
                        height: 6,
                        width: _currentPage == i ? 18 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? currentColor : context.colorTextSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
  
                  // Centered Pill Button with Shake and conditional Shimmer
                  () {
                    Widget pillButton = GestureDetector(
                      onTap: _onNext,
                      child: Opacity(
                        opacity: _isCurrentPageActionCompleted ? 1.0 : 0.5,
                        child: Container(
                          width: 200,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: currentColor,
                            borderRadius: BorderRadius.circular(999), // Fully rounded pill
                            boxShadow: [
                              BoxShadow(
                                color: currentColor.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                                style: context.typographyH3.copyWith(
                                  color: context.colorBackground,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: context.colorBackground,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    // Add shimmer effect only if completed
                    if (_isCurrentPageActionCompleted) {
                      pillButton = pillButton
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.45));
                    }

                    // Wrap in shake animation
                    return Animate(
                      controller: _shakeController,
                      autoPlay: false,
                      effects: const [
                        ShakeEffect(hz: 8, curve: Curves.easeInOut),
                      ],
                      child: pillButton,
                    );
                  }(),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
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
  final bool isBatteryPage;
  final bool isFinalPage;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.hero,
    this.isPermissionPage = false,
    this.isThemePage = false,
    this.isBatteryPage = false,
    this.isFinalPage = false,
  });
}
