import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';


/// Background notification tap handler.
/// Instead of spinning up a new DownloadService (which has empty maps),
/// we route commands through the foreground isolate via IsolateNameServer.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  final id = details.payload;
  final action = details.actionId;
  if (id == null || action == null) return;

  debugPrint('[NotificationService] Action clicked: $action for ID: $id');

  // Send to ALL potential command ports.
  // This ensures that the isolate owning the download task receives the command.
  
  final cmdPort = IsolateNameServer.lookupPortByName('dwldr_cmd_port');
  if (cmdPort != null) {
    debugPrint('[NotificationService] Routing to foreground port');
    cmdPort.send({'action': action, 'id': id});
  }

  final bgPort = IsolateNameServer.lookupPortByName('dwldr_bg_cmd_port');
  if (bgPort != null) {
    debugPrint('[NotificationService] Routing to background port');
    bgPort.send({'action': action, 'id': id});
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _downloadChannelId = 'download_channel';
  static const _completeChannelId = 'download_complete_channel';

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Foreground tap — route to the same handler
        notificationTapBackground(details);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // ── Progress channel (silent, no vibration) ────────────────────────────
    const progressChannel = AndroidNotificationChannel(
      _downloadChannelId,
      'Downloads',
      description: 'Active media download progress',
      importance: Importance.low,
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );

    // ── Completion channel (vibration + sound) ─────────────────────────────
    const completeChannel = AndroidNotificationChannel(
      _completeChannelId,
      'Download Complete',
      description: 'Notifies when a download finishes',
      importance: Importance.high,
      showBadge: true,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(progressChannel);
    await androidPlugin?.createNotificationChannel(completeChannel);
  }

  /// Show or update a download-progress notification.
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    bool showProgress = true,
    bool ongoing = true,
    List<AndroidNotificationAction>? actions,
    String? payload,
  }) async {
    final details = AndroidNotificationDetails(
      _downloadChannelId,
      'Downloads',
      channelDescription: 'Active media download progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: showProgress,
      maxProgress: maxProgress,
      progress: progress,
      ongoing: ongoing,
      onlyAlertOnce: true,
      autoCancel: !ongoing,
      actions: actions,
      color: const Color(0xFF8B5CF6),
      showWhen: false,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: payload,
    );
  }

  /// Show a completion notification on the high-importance channel.
  /// The OS will vibrate the device because the channel has vibration enabled.
  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = AndroidNotificationDetails(
      _completeChannelId,
      'Download Complete',
      channelDescription: 'Notifies when a download finishes',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      color: const Color(0xFF8B5CF6),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }
}
