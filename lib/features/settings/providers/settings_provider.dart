import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsState {
  final String audioQuality;
  final bool highFidelity;
  final bool sleepTimerActive;
  final int sleepTimerMinutes;

  SettingsState({
    this.audioQuality = 'High',
    this.highFidelity = false,
    this.sleepTimerActive = false,
    this.sleepTimerMinutes = 0,
  });

  SettingsState copyWith({
    String? audioQuality,
    bool? highFidelity,
    bool? sleepTimerActive,
    int? sleepTimerMinutes,
  }) {
    return SettingsState(
      audioQuality: audioQuality ?? this.audioQuality,
      highFidelity: highFidelity ?? this.highFidelity,
      sleepTimerActive: sleepTimerActive ?? this.sleepTimerActive,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
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
      audioQuality: box.get('audioQuality', defaultValue: 'High'),
      highFidelity: box.get('highFidelity', defaultValue: false),
    );
  }

  void setAudioQuality(String quality) {
    state = state.copyWith(audioQuality: quality);
    Hive.box('settings_box').put('audioQuality', quality);
  }

  void toggleHighFidelity(bool value) {
    state = state.copyWith(highFidelity: value);
    Hive.box('settings_box').put('highFidelity', value);
  }

  void updateSleepTimer(bool active, int minutes) {
    state = state.copyWith(sleepTimerActive: active, sleepTimerMinutes: minutes);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
