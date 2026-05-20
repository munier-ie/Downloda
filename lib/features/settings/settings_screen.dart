import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _vibrate() {
    if (ref.read(settingsProvider).vibration) {
      HapticFeedback.mediumImpact();
    }
  }

  Widget _switch(bool val, ValueChanged<bool> onChanged) => Transform.scale(
        scale: 0.78,
        child: Switch(
          value: val,
          onChanged: (v) {
            onChanged(v);
            _vibrate();
          },
          activeThumbColor: context.colorAccent,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: context.colorBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SkillHeader(
              greeting: 'Preferences',
              title: 'Settings',
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [

                  // ─── Appearance ───────────────────────────────────────────
                  const SectionHeader(title: 'Appearance'),
                  SettingsTile(
                    icon: Icons.light_mode_rounded,
                    title: 'Light Mode',
                    subtitle: 'Use light appearance',
                    isFirst: true,
                    isLast: true,
                    trailing: _switch(settings.themeMode == 'light', (v) {
                      notifier.update(settings.copyWith(
                          themeMode: v ? 'light' : 'dark'));
                    }),
                  ),

                  // ─── Smart Download Presets ───────────────────────────────
                  const SectionHeader(title: 'Smart Presets'),
                  SettingsTile(
                    icon: Icons.high_quality_rounded,
                    title: 'Default Resolution',
                    subtitle: settings.defaultRes,
                    isFirst: true,
                    onTap: () => _showPicker(
                      context,
                      'Resolution',
                      ['Always Ask', '360p', '480p', '720p', '1080p', '4K'],
                      settings.defaultRes,
                      (v) => notifier.update(settings.copyWith(defaultRes: v)),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.video_file_rounded,
                    title: 'Default Format',
                    subtitle: settings.defaultFormat.toUpperCase(),
                    onTap: () => _showPicker(
                      context,
                      'Format',
                      ['mp4', 'webm', 'mkv'],
                      settings.defaultFormat,
                      (v) =>
                          notifier.update(settings.copyWith(defaultFormat: v)),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.bolt_rounded,
                    title: 'Auto-Download on Share',
                    subtitle: 'Begin immediately, no confirmation',
                    trailing: _switch(settings.autoDownload, (v) {
                      notifier.update(settings.copyWith(autoDownload: v));
                    }),
                  ),
                  SettingsTile(
                    icon: Icons.layers_rounded,
                    title: 'Simultaneous Downloads',
                    subtitle: '${settings.maxSimultaneous} active max',
                    isLast: true,
                    onTap: () => _showPicker(
                      context,
                      'Max Simultaneous',
                      ['1', '2', '3', '4', '5'],
                      '${settings.maxSimultaneous}',
                      (v) => notifier
                          .update(settings.copyWith(maxSimultaneous: int.parse(v))),
                    ),
                  ),

                  // ─── Player ───────────────────────────────────────────────
                  const SectionHeader(title: 'Player'),
                  SettingsTile(
                    icon: Icons.fast_forward_rounded,
                    title: 'Seek Duration',
                    subtitle: '${settings.seekDuration}s per tap',
                    isFirst: true,
                    isLast: true,
                    onTap: () => _showPicker(
                      context,
                      'Seek Duration',
                      ['3', '5', '10', '15', '30'],
                      '${settings.seekDuration}',
                      (v) => notifier
                          .update(settings.copyWith(seekDuration: int.parse(v))),
                    ),
                  ),

                  // ─── Notification Controls ────────────────────────────────
                  const SectionHeader(title: 'Notifications'),
                  SettingsTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Persistent Notifications',
                    subtitle: 'Keep notification during download',
                    isFirst: true,
                    trailing: _switch(settings.persistentNotifs, (v) {
                      notifier.update(settings.copyWith(persistentNotifs: v));
                    }),
                  ),
                  SettingsTile(
                    icon: Icons.compress_rounded,
                    title: 'Compact Mode',
                    subtitle: 'Minimal notification style',
                    trailing: _switch(settings.compactMode, (v) {
                      notifier.update(settings.copyWith(compactMode: v));
                    }),
                  ),
                  SettingsTile(
                    icon: Icons.vibration_rounded,
                    title: 'Vibration on Completion',
                    subtitle: 'Vibrate when a download finishes',
                    isLast: true,
                    trailing: _switch(settings.vibration, (v) {
                      notifier.update(settings.copyWith(vibration: v));
                    }),
                  ),

                  // ─── Battery & Network ────────────────────────────────────
                  const SectionHeader(title: 'Battery & Network'),
                  SettingsTile(
                    icon: Icons.wifi_rounded,
                    title: 'Wi-Fi Only',
                    subtitle: 'Queue downloads on mobile data',
                    isFirst: true,
                    trailing: _switch(settings.wifiOnly, (v) {
                      notifier.update(settings.copyWith(wifiOnly: v));
                    }),
                  ),
                  SettingsTile(
                    icon: Icons.battery_saver_rounded,
                    title: 'Battery Saver Mode',
                    subtitle: 'Limit to 1 concurrent download & reduce speed',
                    isLast: true,
                    trailing: _switch(settings.batterySaver, (v) {
                      notifier.update(settings.copyWith(batterySaver: v));
                    }),
                  ),

                  // ─── About ────────────────────────────────────────────────
                  const SectionHeader(title: 'About'),
                  const SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '1.0.0 (build 1)',
                    isFirst: true,
                    isLast: true,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colorElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colorTextPrimary)),
          ),
          const Divider(height: 1),
          ...options.map((opt) => ListTile(
                dense: true,
                title: Text(opt,
                    style: TextStyle(
                        fontSize: 13,
                        color: opt == current
                            ? context.colorAccent
                            : context.colorTextPrimary)),
                trailing: opt == current
                    ? Icon(Icons.check_rounded,
                        size: 16, color: context.colorAccent)
                    : null,
                onTap: () {
                  onSelect(opt);
                  _vibrate();
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
