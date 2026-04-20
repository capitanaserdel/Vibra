import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PlayHistoryEntry {
  final String songId;
  final DateTime playedAt;
  final String? moment;

  PlayHistoryEntry({
    required this.songId,
    required this.playedAt,
    this.moment,
  });

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'playedAt': playedAt.toIso8601String(),
      'moment': moment,
    };
  }

  factory PlayHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return PlayHistoryEntry(
      songId: map['songId'] as String,
      playedAt: DateTime.parse(map['playedAt'] as String),
      moment: map['moment'] as String?,
    );
  }
}

class MomentsNotifier extends StateNotifier<List<PlayHistoryEntry>> {
  MomentsNotifier() : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final box = Hive.box('play_history_box');
    final history = box.values
        .map((e) => PlayHistoryEntry.fromMap(e as Map))
        .toList();
    state = history;
  }

  Future<void> logPlay(String songId, {String? moment}) async {
    final entry = PlayHistoryEntry(
      songId: songId,
      playedAt: DateTime.now(),
      moment: moment,
    );
    
    final box = Hive.box('play_history_box');
    await box.add(entry.toMap());
    state = [...state, entry];
  }

  // Smart Suggestions: Frequency-based ranking
  List<String> getMostPlayed({int limit = 10}) {
    final counts = <String, int>{};
    for (var entry in state) {
      counts[entry.songId] = (counts[entry.songId] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
  }

  // Smart Suggestions: Recency-based (Recently Played)
  List<String> getRecentlyPlayed({int limit = 10}) {
    final sorted = [...state]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return sorted.map((e) => e.songId).toSet().take(limit).toList();
  }
}

final momentsProvider = StateNotifierProvider<MomentsNotifier, List<PlayHistoryEntry>>((ref) {
  return MomentsNotifier();
});
