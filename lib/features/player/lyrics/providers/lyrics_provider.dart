import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/player/lyrics/services/lyrics_service.dart';

final lyricsServiceProvider = Provider((ref) => LyricsService());

final currentLyricsProvider = FutureProvider<LyricData?>((ref) async {
  final mediaItem = ref.watch(currentMediaItemProvider).value;
  if (mediaItem == null) return null;

  final service = ref.watch(lyricsServiceProvider);
  return service.getLyrics(
    mediaItem.title,
    mediaItem.artist ?? 'Unknown Artist',
    albumName: mediaItem.album,
    durationSeconds: mediaItem.duration?.inSeconds,
  );
});
