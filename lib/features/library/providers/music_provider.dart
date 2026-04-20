import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/features/library/services/music_library_service.dart';
import 'package:music/features/streaming/services/online_music_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

final musicLibraryServiceProvider = Provider((ref) => MusicLibraryService());
final onlineMusicServiceProvider = Provider((ref) => OnlineMusicService());



// Local songs provider
final localSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final service = ref.watch(musicLibraryServiceProvider);
  final allSongs = await service.fetchLocalSongs();
  
  final hiddenBox = Hive.box('hidden_songs_box');
  var filteredSongs = allSongs.where((song) {
    if (hiddenBox.containsKey(song.id)) return false;
    // Physical existence check for UI consistency
    return File(song.data).existsSync();
  }).toList();

  // Apply sorting
  final sortType = ref.watch(librarySortTypeProvider);
  final isAsc = ref.watch(librarySortAscendingProvider);

  filteredSongs.sort((a, b) {
    int result;
    switch (sortType) {
      case LibrarySortType.aToZ:
        result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        break;
      case LibrarySortType.artist:
        result = (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase());
        break;
      case LibrarySortType.dateAdded:
        result = (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0);
        break;
      case LibrarySortType.duration:
        result = (a.duration ?? 0).compareTo(b.duration ?? 0);
        break;
    }
    return isAsc ? result : -result;
  });

  return filteredSongs;
});

// Albums provider
final albumsProvider = FutureProvider<List<AlbumModel>>((ref) async {
  final service = ref.watch(musicLibraryServiceProvider);
  return service.fetchAlbums();
});

// Artists provider
final artistsProvider = FutureProvider<List<ArtistModel>>((ref) async {
  final service = ref.watch(musicLibraryServiceProvider);
  return service.fetchArtists();
});

// Online popular stations provider
final popularStationsProvider = FutureProvider<List<OnlineStation>>((ref) async {
  final service = ref.watch(onlineMusicServiceProvider);
  return service.getPopularStations();
});

// Search stations provider
final searchQueryProvider = StateProvider<String>((ref) => "");

// Library search provider (Offline)
final librarySearchProvider = StateProvider<String>((ref) => "");

// Library Sort Provider
enum LibrarySortType { aToZ, artist, dateAdded, duration }

final librarySortTypeProvider = StateProvider<LibrarySortType>((ref) {
  final box = Hive.box('settings_box');
  final index = box.get('library_sort_index', defaultValue: LibrarySortType.dateAdded.index);
  return LibrarySortType.values[index];
});

final librarySortAscendingProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings_box');
  return box.get('library_sort_ascending', defaultValue: false);
});

// Extension to help updating sorting with persistence
extension SortPersistence on WidgetRef {
  void updateSortType(LibrarySortType type) {
    read(librarySortTypeProvider.notifier).state = type;
    Hive.box('settings_box').put('library_sort_index', type.index);
  }

  void toggleSortDirection() {
    final current = read(librarySortAscendingProvider.notifier).state;
    read(librarySortAscendingProvider.notifier).state = !current;
    Hive.box('settings_box').put('library_sort_ascending', !current);
  }
}

final searchedStationsProvider = FutureProvider<List<OnlineStation>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  
  final service = ref.watch(onlineMusicServiceProvider);
  return service.searchStations(query);
});
