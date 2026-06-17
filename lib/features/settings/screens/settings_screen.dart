import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:music/features/settings/widgets/settings_widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/features/library/providers/music_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final bgPath = settings.appBackgroundImagePath;
    final hasImage = bgPath.isNotEmpty && File(bgPath).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage) ...[
          Positioned.fill(
            child: Image.file(
              File(bgPath),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: settings.appBackgroundBlur,
                sigmaY: settings.appBackgroundBlur,
              ),
              child: Container(
                color: theme.brightness == Brightness.light
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black.withOpacity(0.3),
              ),
            ),
          ),
        ],
        Scaffold(
          backgroundColor: hasImage ? Colors.transparent : theme.colorScheme.background,
          appBar: AppBar(
            title: const Text('SETTINGS'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
            titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
              color: theme.colorScheme.onBackground,
            ),
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
                    const Divider(),
                    SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme Mode',
                      trailing: DropdownButton<String>(
                        value: settings.themeMode,
                        dropdownColor: theme.colorScheme.surface,
                        underline: Container(),
                        items: ['System', 'Light', 'Dark', 'AMOLED'].map((mode) {
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
                        dropdownColor: theme.colorScheme.surface,
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
                        activeColor: theme.primaryColor,
                      ),
                    ),
                    const Divider(),

                    // ── App Background Image ───────────────────────────
                    _AppBackgroundTile(settings: settings, notifier: notifier),
                    const Divider(),

                    // ── Player Page Theme ──────────────────────────────
                    _PlayerThemeTile(settings: settings, notifier: notifier),
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
                SettingsTile(
                  icon: Icons.cloud_outlined,
                  title: 'Search & Streaming Provider',
                  subtitle: 'Change if streaming fails in your region',
                  trailing: ValueListenableBuilder(
                    valueListenable: Hive.box('settings_box').listenable(keys: ['streaming_provider']),
                    builder: (context, box, _) {
                      final provider = box.get('streaming_provider', defaultValue: 'jiosaavn');
                      return DropdownButton<String>(
                        value: provider,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 'jiosaavn', child: Text('JioSaavn (Full, India)')),
                          DropdownMenuItem(value: 'deezer', child: Text('Deezer (Previews, Global)')),
                        ],
                        onChanged: (val) {
                          box.put('streaming_provider', val);
                          ref.invalidate(searchedSongsProvider);
                        },
                      );
                    },
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

            // Music Identification Settings
            SettingsSection(
              title: 'Music Identification',
              children: [
                SettingsTile(
                  icon: Icons.mic_outlined,
                  title: 'AudD API Token',
                  subtitle: 'Tap to set or upgrade your recognition token',
                  onTap: () => _showTokenDialog(context),
                  trailing: Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Synced: History, Moments, Favorites.\nNot synced: Audio files.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
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
    ),
      ],
    );
  }

  void _showFeedback(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8)),
    );
  }

  void _showTokenDialog(BuildContext context) {
    final box = Hive.box('settings_box');
    final currentToken = box.get('audd_api_token', defaultValue: 'test');
    final controller = TextEditingController(text: currentToken == 'test' ? '' : currentToken);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: const Text('AudD API Token'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'By default, Vibra uses a shared "test" token capped at 10 requests/day. Enter your own free/paid token from audd.io to upgrade.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'API Token',
                  hintText: 'e.g. test',
                  labelStyle: TextStyle(color: theme.colorScheme.primary),
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final token = controller.text.trim();
                box.put('audd_api_token', token.isEmpty ? 'test' : token);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AudD API Token updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// App Background Image tile
// ──────────────────────────────────────────────────────────────
class _AppBackgroundTile extends StatelessWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;
  const _AppBackgroundTile({required this.settings, required this.notifier});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      notifier.setAppBackgroundImagePath(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = settings.appBackgroundImagePath.isNotEmpty &&
        File(settings.appBackgroundImagePath).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wallpaper_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Background Image',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface)),
                    Text('Set a wallpaper behind all screens',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
              if (hasImage)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove wallpaper',
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  onPressed: notifier.clearAppBackground,
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pickImage(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasImage
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  width: hasImage ? 2 : 1,
                ),
                image: hasImage
                    ? DecorationImage(
                        image: FileImage(File(settings.appBackgroundImagePath)),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: hasImage ? null : theme.colorScheme.onSurface.withOpacity(0.04),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        color: Colors.black.withOpacity(0.35),
                        child: Center(
                          child: Text('Change image',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 28, color: theme.colorScheme.primary),
                          const SizedBox(height: 4),
                          Text('Choose from gallery',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.blur_on_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  'Blur Intensity: ${settings.appBackgroundBlur.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: settings.appBackgroundBlur,
                min: 0.0,
                max: 20.0,
                onChanged: notifier.setAppBackgroundBlur,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Player Page Theme tile
// ──────────────────────────────────────────────────────────────
class _PlayerThemeTile extends StatelessWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;
  const _PlayerThemeTile({required this.settings, required this.notifier});

  Future<void> _pickPlayerImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      notifier.setPlayerBackgroundImagePath(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme = settings.playerTheme;
    final options = ['Dynamic', 'Solid', 'Image'];
    final icons = [Icons.auto_awesome_rounded, Icons.gradient_rounded, Icons.image_rounded];
    final hasPlayerImage = settings.playerBackgroundImagePath.isNotEmpty &&
        File(settings.playerBackgroundImagePath).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.style_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Player Page Theme',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text('Choose how the player background looks',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented choice chips
          Row(
            children: List.generate(options.length, (i) {
              final opt = options[i];
              final isSelected = currentTheme == opt;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => notifier.setPlayerTheme(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icons[i],
                              size: 20,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(height: 4),
                          Text(opt,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Image picker — only shown when 'Image' is selected
          if (currentTheme == 'Image') ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickPlayerImage(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPlayerImage
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                    width: hasPlayerImage ? 2 : 1,
                  ),
                  image: hasPlayerImage
                      ? DecorationImage(
                          image: FileImage(File(settings.playerBackgroundImagePath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: hasPlayerImage ? null : theme.colorScheme.onSurface.withOpacity(0.04),
                ),
                child: hasPlayerImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Center(
                            child: Text('Change player image',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                          ),
                        ),
                      )
                    : Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 22, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Choose player background image',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6))),
                          ],
                        ),
                      ),
              ),
            ),
            if (hasPlayerImage) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: notifier.clearPlayerBackground,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.blur_on_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Blur Intensity: ${settings.playerBackgroundBlur.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: settings.playerBackgroundBlur,
                  min: 0.0,
                  max: 20.0,
                  onChanged: notifier.setPlayerBackgroundBlur,
                ),
              ),
            ],
          ],

          // Helper text
          const SizedBox(height: 6),
          Text(
            currentTheme == 'Dynamic'
                ? '✦ Background shifts with each song\'s album art'
                : currentTheme == 'Solid'
                    ? '✦ Uses your accent color as a gradient'
                    : '✦ Your chosen image blurred behind the player',
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary.withOpacity(0.8),
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
