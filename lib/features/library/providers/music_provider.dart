import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music/features/library/services/music_library_service.dart';
import 'package:music/features/streaming/services/online_music_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

final musicLibraryServiceProvider = Provider((ref) => MusicLibraryService());
final onlineMusicServiceProvider = Provider((ref) => OnlineMusicService());

// Local songs provider
final localSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final service = ref.watch(musicLibraryServiceProvider);
  return service.fetchLocalSongs();
});

// Online popular stations provider
final popularStationsProvider = FutureProvider<List<OnlineStation>>((ref) async {
  final service = ref.watch(onlineMusicServiceProvider);
  return service.getPopularStations();
});

// Search stations provider
final searchQueryProvider = StateProvider<String>((ref) => "");

final searchedStationsProvider = FutureProvider<List<OnlineStation>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  
  final service = ref.watch(onlineMusicServiceProvider);
  return service.searchStations(query);
});
