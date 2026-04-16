import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music/main.dart'; // To access audioHandler

class SleepTimerState {
  final bool isActive;
  final Duration remaining;

  SleepTimerState({
    this.isActive = false,
    this.remaining = Duration.zero,
  });
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  Timer? _timer;

  SleepTimerNotifier() : super(SleepTimerState());

  void setTimer(int minutes) {
    _timer?.cancel();
    state = SleepTimerState(
      isActive: true,
      remaining: Duration(minutes: minutes),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remaining.inSeconds <= 0) {
        _timer?.cancel();
        state = SleepTimerState(isActive: false, remaining: Duration.zero);
        _stopPlayback();
      } else {
        state = SleepTimerState(
          isActive: true,
          remaining: state.remaining - const Duration(seconds: 1),
        );
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    state = SleepTimerState(isActive: false, remaining: Duration.zero);
  }

  void _stopPlayback() {
    audioHandler.pause();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier();
});
