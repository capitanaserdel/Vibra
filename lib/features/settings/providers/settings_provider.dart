import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsState {
  // Appearance
  final String themeMode; // 'System', 'Light', 'Dark', 'AMOLED'
  final String accentColor; // 'Green', 'Blue', 'Purple', 'Orange'
  final bool visualizerEnabled;
  final String playerStyle; // 'Circle', 'Linear'

  /// Path to user-picked wallpaper image for the app background. Empty = none.
  final String appBackgroundImagePath;

  /// Player page visual theme: 'Dynamic' | 'Solid' | 'Image'
  final String playerTheme;

  /// Path to user-picked image for the player background (only used when playerTheme == 'Image')
  final String playerBackgroundImagePath;

  // Playback
  final bool autoPlayNext;
  final bool resumeSession;
  final String streamingQuality;
  final bool backgroundPlayback;

  // Library
  final bool autoSaveDownloads;
  final bool preventDuplicates;

  // Moments
  final bool smartSuggestions;
  final bool autoAddSongs;

  // Sync
  final bool syncEnabled;
  final String lastSyncTime;

  SettingsState({
    this.themeMode = 'System',
    this.accentColor = 'Green',
    this.visualizerEnabled = true,
    this.playerStyle = 'Circle',
    this.appBackgroundImagePath = '',
    this.playerTheme = 'Dynamic',
    this.playerBackgroundImagePath = '',
    this.autoPlayNext = true,
    this.resumeSession = true,
    this.streamingQuality = 'High',
    this.backgroundPlayback = true,
    this.autoSaveDownloads = true,
    this.preventDuplicates = true,
    this.smartSuggestions = true,
    this.autoAddSongs = true,
    this.syncEnabled = false,
    this.lastSyncTime = 'Never',
  });

  SettingsState copyWith({
    String? themeMode,
    String? accentColor,
    bool? visualizerEnabled,
    String? playerStyle,
    String? appBackgroundImagePath,
    String? playerTheme,
    String? playerBackgroundImagePath,
    bool? autoPlayNext,
    bool? resumeSession,
    String? streamingQuality,
    bool? backgroundPlayback,
    bool? autoSaveDownloads,
    bool? preventDuplicates,
    bool? smartSuggestions,
    bool? autoAddSongs,
    bool? syncEnabled,
    String? lastSyncTime,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      playerStyle: playerStyle ?? this.playerStyle,
      appBackgroundImagePath: appBackgroundImagePath ?? this.appBackgroundImagePath,
      playerTheme: playerTheme ?? this.playerTheme,
      playerBackgroundImagePath: playerBackgroundImagePath ?? this.playerBackgroundImagePath,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      resumeSession: resumeSession ?? this.resumeSession,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      autoSaveDownloads: autoSaveDownloads ?? this.autoSaveDownloads,
      preventDuplicates: preventDuplicates ?? this.preventDuplicates,
      smartSuggestions: smartSuggestions ?? this.smartSuggestions,
      autoAddSongs: autoAddSongs ?? this.autoAddSongs,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final box = Hive.box('settings_box');
    state = SettingsState(
      themeMode: box.get('themeMode', defaultValue: 'System'),
      accentColor: box.get('accentColor', defaultValue: 'Green'),
      visualizerEnabled: box.get('visualizerEnabled', defaultValue: true),
      playerStyle: box.get('playerStyle', defaultValue: 'Circle'),
      appBackgroundImagePath: box.get('appBackgroundImagePath', defaultValue: ''),
      playerTheme: box.get('playerTheme', defaultValue: 'Dynamic'),
      playerBackgroundImagePath: box.get('playerBackgroundImagePath', defaultValue: ''),
      autoPlayNext: box.get('autoPlayNext', defaultValue: true),
      resumeSession: box.get('resumeSession', defaultValue: true),
      streamingQuality: box.get('streamingQuality', defaultValue: 'High'),
      backgroundPlayback: box.get('backgroundPlayback', defaultValue: true),
      autoSaveDownloads: box.get('autoSaveDownloads', defaultValue: true),
      preventDuplicates: box.get('preventDuplicates', defaultValue: true),
      smartSuggestions: box.get('smartSuggestions', defaultValue: true),
      autoAddSongs: box.get('autoAddSongs', defaultValue: true),
      syncEnabled: box.get('syncEnabled', defaultValue: false),
      lastSyncTime: box.get('lastSyncTime', defaultValue: 'Never'),
    );
  }

  // Setters with Persistence
  void _update(SettingsState newState) {
    state = newState;
    final box = Hive.box('settings_box');
    box.put('themeMode', state.themeMode);
    box.put('accentColor', state.accentColor);
    box.put('visualizerEnabled', state.visualizerEnabled);
    box.put('playerStyle', state.playerStyle);
    box.put('appBackgroundImagePath', state.appBackgroundImagePath);
    box.put('playerTheme', state.playerTheme);
    box.put('playerBackgroundImagePath', state.playerBackgroundImagePath);
    box.put('autoPlayNext', state.autoPlayNext);
    box.put('resumeSession', state.resumeSession);
    box.put('streamingQuality', state.streamingQuality);
    box.put('backgroundPlayback', state.backgroundPlayback);
    box.put('autoSaveDownloads', state.autoSaveDownloads);
    box.put('preventDuplicates', state.preventDuplicates);
    box.put('smartSuggestions', state.smartSuggestions);
    box.put('autoAddSongs', state.autoAddSongs);
    box.put('syncEnabled', state.syncEnabled);
    box.put('lastSyncTime', state.lastSyncTime);
  }

  void setThemeMode(String mode) => _update(state.copyWith(themeMode: mode));
  void setAccentColor(String color) => _update(state.copyWith(accentColor: color));
  void toggleVisualizer(bool value) => _update(state.copyWith(visualizerEnabled: value));
  void setPlayerStyle(String style) => _update(state.copyWith(playerStyle: style));
  void setAppBackgroundImagePath(String path) => _update(state.copyWith(appBackgroundImagePath: path));
  void setPlayerTheme(String theme) => _update(state.copyWith(playerTheme: theme));
  void setPlayerBackgroundImagePath(String path) => _update(state.copyWith(playerBackgroundImagePath: path));
  void clearAppBackground() => _update(state.copyWith(appBackgroundImagePath: ''));
  void clearPlayerBackground() => _update(state.copyWith(playerBackgroundImagePath: ''));
  
  void setAutoPlayNext(bool value) => _update(state.copyWith(autoPlayNext: value));
  void setResumeSession(bool value) => _update(state.copyWith(resumeSession: value));
  void setStreamingQuality(String q) => _update(state.copyWith(streamingQuality: q));
  void setBackgroundPlayback(bool value) => _update(state.copyWith(backgroundPlayback: value));

  void setAutoSave(bool value) => _update(state.copyWith(autoSaveDownloads: value));
  void setPreventDuplicates(bool value) => _update(state.copyWith(preventDuplicates: value));

  void setSmartSuggestions(bool value) => _update(state.copyWith(smartSuggestions: value));
  void setAutoAddSongs(bool value) => _update(state.copyWith(autoAddSongs: value));
  
  void toggleSync(bool value) => _update(state.copyWith(syncEnabled: value));
  void updateSyncTime() => _update(state.copyWith(lastSyncTime: DateTime.now().toString().split('.')[0]));

  // Functional Utility Actions
  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> resetMomentsData() async {
    final box = Hive.box('play_history_box');
    await box.clear();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
