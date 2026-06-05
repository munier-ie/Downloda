import 'dart:isolate';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' as drift;
import 'core/theme.dart';
import 'core/models.dart';
import 'core/database/database.dart';
import 'core/services/notification_service.dart';
import 'core/providers.dart';
import 'core/services/download_service.dart';

import 'features/downloads/downloads_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/whatsapp/whatsapp_screen.dart';

import 'features/onboarding/onboarding_screen.dart';

// ── WorkManager background dispatcher ───────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    AppDatabase? db;
    try {
      if (task == 'shareDownloadTask') {
        final url =
            (inputData?['url'] ?? inputData?['payload_url']) as String?;
        if (url == null || url.isEmpty) {
          debugPrint('[BG] shareDownloadTask: no URL');
          return false;
        }

        final urlRegExp =
            RegExp(r'https?://[^\s]+', caseSensitive: false);
        final cleanUrl = urlRegExp.firstMatch(url)?.group(0) ?? url;
        debugPrint('[BG] shareDownloadTask: queuing $cleanUrl');

        db = AppDatabase();

        MediaPlatform platform = MediaPlatform.youtube;
        if (cleanUrl.contains('instagram')) {
          platform = MediaPlatform.instagram;
        } else if (cleanUrl.contains('tiktok')) {
          platform = MediaPlatform.tiktok;
        } else if (cleanUrl.contains('facebook') ||
            cleanUrl.contains('fb.watch')) {
          platform = MediaPlatform.facebook;
        } else if (cleanUrl.contains('x.com') ||
            cleanUrl.contains('twitter.com')) {
          platform = MediaPlatform.x;
        } else if (cleanUrl.contains('reddit.com') ||
            cleanUrl.contains('redd.it')) {
          platform = MediaPlatform.reddit;
        }

        // Check if user has "Always Ask" resolution — queue with marker 'ask'
        final prefs = await SharedPreferences.getInstance();
        final defaultRes = prefs.getString('defaultRes') ?? '1080p';
        final resolution =
            defaultRes == 'Always Ask' ? 'ask' : defaultRes;

        final id = const Uuid().v4();
        final item = DownloadItem(
          id: id,
          title: 'Queued from share...',
          url: cleanUrl,
          platform: platform,
          status: DownloadStatus.queued,
          progress: 0,
          speedMbps: 0,
          etaSeconds: 0,
          format: '...',
          resolution: resolution, // 'ask' = needs user to pick resolution
          fileSizeMb: 0,
          addedAt: DateTime.now(),
        );
        await db.insertDownload(item.toCompanion());

        final notif = NotificationService();
        await notif.initialize();

        if (resolution == 'ask') {
          await notif.showProgressNotification(
            id: id.hashCode & 0x7fffffff,
            title: 'Select Quality',
            body: 'Open Downloda to choose download quality',
            progress: 0,
            maxProgress: 100,
            showProgress: false,
            ongoing: false,
            payload: id,
          );
        } else {
          await notif.showProgressNotification(
            id: id.hashCode & 0x7fffffff,
            title: 'Download Queued',
            body: 'Open Downloda to start downloading',
            progress: 0,
            maxProgress: 100,
            showProgress: false,
            ongoing: false,
            payload: id,
          );
        }
        debugPrint('[BG] shareDownloadTask: queued id=$id, res=$resolution');
      }
      return true;
    } catch (e, st) {
      debugPrint('[BG] shareDownloadTask error: $e\n$st');
      return false;
    } finally {
      await db?.close();
    }
  });
}

// ── Foreground service entrypoint (share-download) ────────────────────────────

@pragma('vm:entry-point')
void shareDownloadBackgroundEntrypoint() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final MethodChannel channel =
      const MethodChannel('com.downloda.app/share_download');

  AppDatabase? db;
  final ReceivePort bgCmdPort = ReceivePort();

  IsolateNameServer.removePortNameMapping('dwldr_bg_cmd_port');
  IsolateNameServer.registerPortWithName(
      bgCmdPort.sendPort, 'dwldr_bg_cmd_port');

  channel.setMethodCallHandler((call) async {
    if (call.method == 'startDownload') {
      final url = call.arguments as String?;
      if (url == null) return;

      debugPrint('[FG Service] startDownload: $url');

      db ??= AppDatabase();
      final notif = NotificationService();
      await notif.initialize();

      final service = DownloadService(db!);

      try {
        await service.downloadVideo(url);
      } catch (e) {
        debugPrint('[FG Service] startDownload error: $e');
      } finally {
        await Future.delayed(const Duration(seconds: 2));
        final activeCount = await service.getActiveCount();
        if (activeCount == 0) {
          await channel.invokeMethod('stopService');
          IsolateNameServer.removePortNameMapping('dwldr_bg_cmd_port');
          bgCmdPort.close();
          await db?.close();
          db = null;
        }
      }
    }
  });

  bgCmdPort.listen((dynamic msg) async {
    if (msg is! Map) return;
    final action = msg['action'] as String?;
    final id = msg['id'] as String?;
    if (id == null) return;

    db ??= AppDatabase();
    final service = DownloadService(db!);

    switch (action) {
      case 'pause':
        await service.pauseDownload(id, broadcast: false);
        break;
      case 'resume':
        final item = await db!.getDownloadById(id);
        if (item != null) {
          await service.resumeDownload(id, item.url, broadcast: false);
        }
        break;
      case 'cancel':
        await service.cancelDownload(id, broadcast: false);
        break;
    }
  });

  channel.invokeMethod('engineReady');
}

// ── App entry point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  Workmanager().initialize(callbackDispatcher);
  await Permission.notification.request();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const DwldrApp(),
  ));
}

class DwldrApp extends ConsumerWidget {
  const DwldrApp({super.key});

  ThemeMode _parseThemeMode(String? mode) {
    if (mode == null) return ThemeMode.dark;
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final prefs = ref.watch(sharedPrefsProvider);
      final settings = ref.watch(settingsProvider);
      final mode = _parseThemeMode(settings.themeMode);

      final brightness = View.of(context).platformDispatcher.platformBrightness;
      final isDark = mode == ThemeMode.dark ||
          (mode == ThemeMode.system && brightness == Brightness.dark);
      
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ));

      return MaterialApp(
        title: 'Downloda',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: DwldrTheme.lightTheme,
        darkTheme: DwldrTheme.darkTheme,
        home: prefs.getBool('onboarding_complete') == true
            ? const AppShell()
            : const OnboardingScreen(),
      );
    } catch (e, stack) {
      debugPrint('Error building DwldrApp: $e\n$stack');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DwldrTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('Something went wrong',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(settingsProvider),
                    child: const Text('Reset Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}

// ── App shell ─────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Receives commands from notification actions & completion pings
  final ReceivePort _cmdPort = ReceivePort();

  /// Receives refresh requests from isolates (e.g. downloads complete)
  final ReceivePort _uiPort = ReceivePort();

  /// Listens for connectivity changes to auto-resume when WiFi reconnects
  late final Stream<List<ConnectivityResult>> _connectivityStream;

  final _screens = const [
    DownloadsScreen(),
    HistoryScreen(),
    WhatsappScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register the command port so notifications can reach us
    IsolateNameServer.removePortNameMapping('dwldr_cmd_port');
    IsolateNameServer.registerPortWithName(
        _cmdPort.sendPort, 'dwldr_cmd_port');

    _cmdPort.listen(_handleCommand);

    // Central UI port to watch for refresh triggers (both active & history lists)
    IsolateNameServer.removePortNameMapping('dwldr_ui_port');
    IsolateNameServer.registerPortWithName(
        _uiPort.sendPort, 'dwldr_ui_port');

    _uiPort.listen((dynamic msg) {
      if (msg == 'refresh' && mounted) {
        ref.invalidate(activeDownloadsProvider);
        ref.invalidate(historyDownloadsProvider);
      }
    });

    // Reset stuck active downloads (preparing/downloading/processing) to paused on start
    ref.read(downloadServiceProvider).resetActiveDownloadsToPaused();

    // WiFi reconnect watcher
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen(_onConnectivityChanged);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncAndQueue());

    // Initialize notification channels
    NotificationService().initialize();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('dwldr_cmd_port');
    IsolateNameServer.removePortNameMapping('dwldr_ui_port');
    _cmdPort.close();
    _uiPort.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAndQueue();
    }
  }

  // ── Command dispatcher (from notification actions & completion) ──────────

  void _handleCommand(dynamic msg) {
    if (msg is! Map) return;
    final action = msg['action'] as String?;
    final id = msg['id'] as String?;

    switch (action) {
      case 'pause':
        if (id != null) {
          ref.read(downloadServiceProvider).pauseDownload(id, broadcast: false);
        }
        break;
      case 'resume':
        if (id != null) {
          ref
              .read(databaseProvider)
              .getDownloadById(id)
              .then((item) {
            if (item != null) {
              ref
                  .read(downloadServiceProvider)
                  .resumeDownload(id, item.url, broadcast: false);
            }
          });
        }
        break;
      case 'cancel':
        if (id != null) {
          ref.read(downloadServiceProvider).cancelDownload(id, broadcast: false);
        }
        break;
      case 'vibrate':
        // Triggered by download service on completion when vibration is enabled
        HapticFeedback.heavyImpact();
        break;
    }
  }

  // ── Connectivity watcher ─────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    if (hasWifi) {
      debugPrint('[ConnectivityWatcher] Wi-Fi reconnected — checking queue');
      _syncAndQueue();
    }
  }

  // ── Sync & queue ─────────────────────────────────────────────────────────

  void _syncAndQueue() {
    if (!mounted) return;
    ref.invalidate(activeDownloadsProvider);
    final service = ref.read(downloadServiceProvider);
    service.syncLocalDownloads();
    service.checkQueue();

    // Check for items queued with resolution='ask' (from share intent)
    _checkAskResolutionItems();
  }

  /// Finds items queued with resolution='ask' and prompts the user
  /// to pick a quality before starting them.
  Future<void> _checkAskResolutionItems() async {
    final db = ref.read(databaseProvider);
    final active = await db.getActiveDownloads();
    final askItems = active
        .where((i) =>
            i.status == DownloadStatus.queued && i.resolution == 'ask')
        .toList();

    if (askItems.isEmpty || !mounted) return;

    // Show picker for the first pending item
    final item = askItems.first;
    _showShareResolutionPicker(item.id, item.url, item.title);
  }

  void _showShareResolutionPicker(String id, String url, String title) {
    if (!mounted) return;
    final options = ['360p', '480p', '720p', '1080p', '4K'];
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: context.colorElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colorDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Quality',
                      style: context.typographyH2),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: context.colorTextSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ...options.map((opt) => ListTile(
                  title: Text(opt,
                      style:
                          TextStyle(color: context.colorTextPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Update the item's resolution and resume
                    ref
                        .read(databaseProvider)
                        .getDownloadById(id)
                        .then((existing) async {
                      if (existing != null) {
                        // Update resolution in DB so checkQueue picks correct res
                        final updated = existing.toCompanion(false).copyWith(
                          resolution: drift.Value(opt),
                        );
                        await ref
                            .read(databaseProvider)
                            .updateDownload(updated);
                        ref
                            .read(downloadServiceProvider)
                            .resumeDownload(id, url);
                      }
                    });
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBackground,
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _CustomNavbarContainer(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ── Redesigned Floating Bottom Navigation ────────────────────────────────────

class _CustomNavbarContainer extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomNavbarContainer({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInputVisible = ref.watch(inputVisibleProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Pill Navbar
          Expanded(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: context.colorSurface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: context.colorDivider.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PillNavItem(
                          icon: Icons.download_rounded,
                          label: 'Downloads',
                          isSelected: currentIndex == 0,
                          onTap: () => onTap(0),
                        ),
                        _PillNavItem(
                          icon: Icons.history_rounded,
                          label: 'History',
                          isSelected: currentIndex == 1,
                          onTap: () => onTap(1),
                        ),
                        _PillNavItem(
                          imagePath: 'assets/images/whatsapp_logo.png',
                          label: 'Status',
                          isSelected: currentIndex == 2,
                          onTap: () => onTap(2),
                        ),
                        _PillNavItem(
                          icon: Icons.tune_rounded,
                          label: 'Settings',
                          isSelected: currentIndex == 3,
                          onTap: () => onTap(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Circular FAB
          GestureDetector(
            onTap: () {
              ref.read(inputVisibleProvider.notifier).toggle();
              // If we are not on the Downloads screen, switch to it
              if (currentIndex != 0) {
                onTap(0);
              }
            },
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: context.colorAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colorAccent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: isInputVisible ? 0.125 : 0, // Slight rotation for effect if desired, or just swap icon
                child: Icon(
                  isInputVisible ? Icons.remove_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillNavItem({
    this.icon,
    this.imagePath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: isSelected ? 3 : 2,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 12 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? context.colorAccent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              imagePath != null
                  ? Image.asset(
                      imagePath!,
                      width: 22,
                      height: 22,
                      color: isSelected ? null : context.colorTextSecondary.withValues(alpha: 0.6),
                      colorBlendMode: isSelected ? null : BlendMode.modulate,
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: isSelected ? context.colorAccent : context.colorTextSecondary,
                    ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: context.typographyTab.copyWith(
                      color: context.colorAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

