import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:music/features/settings/widgets/settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            // 1. APPEARANCE
            SettingsSection(
              title: 'Appearance',
              children: [
                SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Accent Color',
                  trailing: const SizedBox.shrink(),
                ),
                AccentColorTile(
                  selectedColor: settings.accentColor,
                  onSelected: (color) => notifier.setAccentColor(color),
                ),
                const Divider(color: Colors.white10),
                SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme Mode',
                  trailing: DropdownButton<String>(
                    value: settings.themeMode,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    underline: Container(),
                    items: ['Light', 'Dark', 'AMOLED'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                    onChanged: (val) => notifier.setThemeMode(val!),
                  ),
                ),
                SettingsTile(
                  icon: Icons.aspect_ratio_outlined,
                  title: 'Player Style',
                  trailing: DropdownButton<String>(
                    value: settings.playerStyle,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    underline: Container(),
                    items: ['Circle', 'Linear'].map((style) {
                      return DropdownMenuItem(value: style, child: Text(style));
                    }).toList(),
                    onChanged: (val) => notifier.setPlayerStyle(val!),
                  ),
                ),
                SettingsTile(
                  icon: Icons.waves_outlined,
                  title: 'Show Visualizer',
                  trailing: Switch(
                    value: settings.visualizerEnabled,
                    onChanged: notifier.toggleVisualizer,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),

            // 2. PLAYBACK
            SettingsSection(
              title: 'Playback',
              children: [
                SettingsTile(
                  icon: Icons.skip_next_outlined,
                  title: 'Auto-play Next',
                  subtitle: 'Continue to the next song automatically',
                  trailing: Switch(
                    value: settings.autoPlayNext,
                    onChanged: notifier.setAutoPlayNext,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.history_outlined,
                  title: 'Resume Last Session',
                  subtitle: 'Restore song and position on startup',
                  trailing: Switch(
                    value: settings.resumeSession,
                    onChanged: notifier.setResumeSession,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.high_quality_outlined,
                  title: 'Streaming Quality',
                  trailing: DropdownButton<String>(
                    value: settings.streamingQuality,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    underline: Container(),
                    items: ['Low', 'Medium', 'High'].map((q) {
                      return DropdownMenuItem(value: q, child: Text(q));
                    }).toList(),
                    onChanged: (val) => notifier.setStreamingQuality(val!),
                  ),
                ),
              ],
            ),

            // 3. LIBRARY & STORAGE
            SettingsSection(
              title: 'Library & Storage',
              children: [
                SettingsTile(
                  icon: Icons.folder_open_outlined,
                  title: 'Download Location',
                  subtitle: '/storage/emulated/0/Vibra/music/',
                ),
                SettingsTile(
                  icon: Icons.save_alt_outlined,
                  title: 'Auto-save Downloads',
                  trailing: Switch(
                    value: settings.autoSaveDownloads,
                    onChanged: notifier.setAutoSave,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.copy_outlined,
                  title: 'Prevent Duplicates',
                  trailing: Switch(
                    value: settings.preventDuplicates,
                    onChanged: notifier.setPreventDuplicates,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Cache',
                  subtitle: 'Temporary files & album art',
                  onTap: () async {
                    await notifier.clearCache();
                    _showFeedback(context, 'Cache cleared!');
                  },
                ),
                SettingsTile(
                  icon: Icons.sync_outlined,
                  title: 'Scan for New Music',
                  onTap: () {
                    // Trigger scan
                    _showFeedback(context, 'Scan started...');
                  },
                ),
              ],
            ),

            // 4. MOMENTS
            SettingsSection(
              title: 'Moments',
              children: [
                SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Smart Suggestions',
                  subtitle: 'Detect patterns automatically',
                  trailing: Switch(
                    value: settings.smartSuggestions,
                    onChanged: notifier.setSmartSuggestions,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.add_to_photos_outlined,
                  title: 'Auto-add Songs',
                  subtitle: 'Add frequently played songs to Moments',
                  trailing: Switch(
                    value: settings.autoAddSongs,
                    onChanged: notifier.setAutoAddSongs,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                SettingsTile(
                  icon: Icons.refresh_outlined,
                  title: 'Reset Moments Data',
                  onTap: () async {
                    await notifier.resetMomentsData();
                    _showFeedback(context, 'History & Moments data reset');
                  },
                ),
              ],
            ),

            // 5. SYNC & ACCOUNT
            SettingsSection(
              title: 'Sync & Account',
              children: [
                SettingsTile(
                  icon: Icons.account_circle_outlined,
                  title: 'Sign in with phone number',
                  onTap: () {},
                ),
                SettingsTile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Sync data across devices',
                  trailing: Switch(
                    value: settings.syncEnabled,
                    onChanged: notifier.toggleSync,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
                if (settings.syncEnabled) ...[
                  SettingsTile(
                    icon: Icons.sync_rounded,
                    title: 'Sync now',
                    subtitle: 'Last synced: ${settings.lastSyncTime}',
                    onTap: () => notifier.updateSyncTime(),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Synced: History, Moments, Favorites.\nNot synced: Audio files.',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ),
              ],
            ),

            // 6. ABOUT
            SettingsSection(
              title: 'About',
              children: [
                const SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Vibra Version',
                  subtitle: '1.0.0 (Production Ready)',
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8)),
    );
  }
}
