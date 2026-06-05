import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database.dart';
import 'services/download_service.dart';
import 'services/conversion_service.dart';
import 'services/social_download_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final activeDownloadsProvider = StreamProvider<List<DownloadItemData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveDownloads();
});

final historyDownloadsProvider = StreamProvider<List<DownloadItemData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchHistory();
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final db = ref.watch(databaseProvider);
  return DownloadService(db);
});

final socialDownloadServiceProvider = Provider<SocialDownloadService>((ref) {
  return SocialDownloadService();
});

final conversionServiceProvider = Provider<ConversionService>((ref) {
  final db = ref.watch(databaseProvider);
  return ConversionService(db);
});

final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

// ── App Settings ──────────────────────────────────────────────────────────────

class AppSettings {
  final String defaultRes;
  final String defaultFormat;
  final bool autoDownload;
  final int maxSimultaneous;
  final bool persistentNotifs;
  final bool compactMode;
  final bool vibration;
  final bool wifiOnly;
  final bool batterySaver;
  final int seekDuration;
  final String themeMode;

  AppSettings({
    String? defaultRes,
    String? defaultFormat,
    bool? autoDownload,
    int? maxSimultaneous,
    bool? persistentNotifs,
    bool? compactMode,
    bool? vibration,
    bool? wifiOnly,
    bool? batterySaver,
    int? seekDuration,
    String? themeMode,
  })  : defaultRes = defaultRes ?? '720p',
        defaultFormat = defaultFormat ?? 'mp4',
        autoDownload = autoDownload ?? true,
        maxSimultaneous = maxSimultaneous ?? 3,
        persistentNotifs = persistentNotifs ?? true,
        compactMode = compactMode ?? false,
        vibration = vibration ?? true,
        wifiOnly = wifiOnly ?? false,
        batterySaver = batterySaver ?? false,
        seekDuration = seekDuration ?? 5,
        themeMode = themeMode ?? 'light';

  AppSettings copyWith({
    String? defaultRes,
    String? defaultFormat,
    bool? autoDownload,
    int? maxSimultaneous,
    bool? persistentNotifs,
    bool? compactMode,
    bool? vibration,
    bool? wifiOnly,
    bool? batterySaver,
    int? seekDuration,
    String? themeMode,
  }) {
    return AppSettings(
      defaultRes: defaultRes ?? this.defaultRes,
      defaultFormat: defaultFormat ?? this.defaultFormat,
      autoDownload: autoDownload ?? this.autoDownload,
      maxSimultaneous: maxSimultaneous ?? this.maxSimultaneous,
      persistentNotifs: persistentNotifs ?? this.persistentNotifs,
      compactMode: compactMode ?? this.compactMode,
      vibration: vibration ?? this.vibration,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      batterySaver: batterySaver ?? this.batterySaver,
      seekDuration: seekDuration ?? this.seekDuration,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return AppSettings(
      defaultRes: prefs.getString('defaultRes') ?? '720p',
      defaultFormat: prefs.getString('defaultFormat') ?? 'mp4',
      autoDownload: prefs.getBool('autoDownload') ?? true,
      maxSimultaneous: prefs.getInt('maxSimultaneous') ?? 3,
      persistentNotifs: prefs.getBool('persistentNotifs') ?? true,
      compactMode: prefs.getBool('compactMode') ?? false,
      vibration: prefs.getBool('vibration') ?? true,
      wifiOnly: prefs.getBool('wifiOnly') ?? false,
      batterySaver: prefs.getBool('batterySaver') ?? false,
      seekDuration: prefs.getInt('seekDuration') ?? 5,
      themeMode: prefs.getString('themeMode') ?? 'light',
    );
  }

  void update(AppSettings settings) {
    state = settings;
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString('defaultRes', settings.defaultRes);
    prefs.setString('defaultFormat', settings.defaultFormat);
    prefs.setBool('autoDownload', settings.autoDownload);
    prefs.setInt('maxSimultaneous', settings.maxSimultaneous);
    prefs.setBool('persistentNotifs', settings.persistentNotifs);
    prefs.setBool('compactMode', settings.compactMode);
    prefs.setBool('vibration', settings.vibration);
    prefs.setBool('wifiOnly', settings.wifiOnly);
    prefs.setBool('batterySaver', settings.batterySaver);
    prefs.setInt('seekDuration', settings.seekDuration);
    prefs.setString('themeMode', settings.themeMode);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class InputVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final inputVisibleProvider =
    NotifierProvider<InputVisibleNotifier, bool>(InputVisibleNotifier.new);
