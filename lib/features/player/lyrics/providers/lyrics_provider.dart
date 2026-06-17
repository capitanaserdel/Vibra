import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/utils/metadata_helper.dart';
import '../../providers/player_provider.dart';
import '../services/lyrics_service.dart';

final lyricsServiceProvider = Provider((ref) => LyricsService());

// State holder for user-corrected search queries: parameter is trackId, value is {'title': '...', 'artist': '...'}
final manualLyricsQueryProvider = StateProvider.family<Map<String, String>?, String>((ref, trackId) => null);

final currentLyricsProvider = FutureProvider.family<LyricData?, MediaItem>((ref, mediaItem) async {
  final manualQuery = ref.watch(manualLyricsQueryProvider(mediaItem.id));
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
