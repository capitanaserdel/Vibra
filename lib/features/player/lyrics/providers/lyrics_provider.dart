import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/utils/metadata_helper.dart';
import '../../providers/player_provider.dart';
import '../services/lyrics_service.dart';

final lyricsServiceProvider = Provider((ref) => LyricsService());

// State holder for user-corrected search queries: {'title': '...', 'artist': '...'}
final manualLyricsQueryProvider = StateProvider<Map<String, String>?>((ref) => null);

final currentLyricsProvider = FutureProvider<LyricData?>((ref) async {
  final mediaItem = ref.watch(currentMediaItemProvider).value;
  if (mediaItem == null) return null;

  // Clear manual search when track changes to prevent logic leak
  ref.listen(currentMediaItemProvider, (previous, next) {
    if (previous?.value?.id != next.value?.id) {
      ref.read(manualLyricsQueryProvider.notifier).state = null;
    }
  });

  final manualQuery = ref.watch(manualLyricsQueryProvider);
  final service = ref.watch(lyricsServiceProvider);
  
  if (manualQuery != null) {
    // Stage 0: Priority Manual Search
    return service.getLyrics(
      mediaItem.title,
      mediaItem.artist ?? '',
      customTrackName: manualQuery['title'],
      customArtistName: manualQuery['artist'],
    );
  }

  // Clean inputs for better API hits
  final cleanTitle = MetadataHelper.stripNoise(mediaItem.title);
  final cleanArtist = MetadataHelper.getMainArtist(mediaItem.artist);

  return service.getLyrics(
    cleanTitle,
    cleanArtist,
    albumName: mediaItem.album,
    durationSeconds: mediaItem.duration?.inSeconds,
  );
});
