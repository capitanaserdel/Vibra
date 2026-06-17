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
      case LibrarySortType.songName:
        final titleA = a.title.trim().toUpperCase();
        final titleB = b.title.trim().toUpperCase();
        
        final isLetterA = titleA.isNotEmpty && RegExp(r'[A-Z]').hasMatch(titleA[0]);
        final isLetterB = titleB.isNotEmpty && RegExp(r'[A-Z]').hasMatch(titleB[0]);
        
        if (isLetterA && !isLetterB) {
          result = -1;
        } else if (!isLetterA && isLetterB) {
          result = 1;
        } else {
          result = titleA.compareTo(titleB);
        }
        break;
      case LibrarySortType.artistName:
        result = (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase());
        break;
      case LibrarySortType.albumName:
        result = (a.album ?? '').toLowerCase().compareTo((b.album ?? '').toLowerCase());
        break;
      case LibrarySortType.folderName:
        final folderA = File(a.data).parent.path.split('/').last;
        final folderB = File(b.data).parent.path.split('/').last;
        result = folderA.toLowerCase().compareTo(folderB.toLowerCase());
        break;
      case LibrarySortType.addedTime:
        result = (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0);
        break;
      case LibrarySortType.duration:
        result = (a.duration ?? 0).compareTo(b.duration ?? 0);
        break;
      case LibrarySortType.year:
        final yearA = a.getMap["year"];
        final yearB = b.getMap["year"];
        final yA = yearA is int ? yearA : (int.tryParse(yearA?.toString() ?? '') ?? 0);
        final yB = yearB is int ? yearB : (int.tryParse(yearB?.toString() ?? '') ?? 0);
        result = yA.compareTo(yB);
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
enum LibrarySortType {
  songName,
  artistName,
  albumName,
  folderName,
  addedTime,
  duration,
  year,
}

final librarySortTypeProvider = StateProvider<LibrarySortType>((ref) {
  final box = Hive.box('settings_box');
  final index = box.get('library_sort_index', defaultValue: LibrarySortType.songName.index);
  return LibrarySortType.values[index];
});

final librarySortAscendingProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings_box');
  return box.get('library_sort_ascending', defaultValue: true);
});

// Track click count for songs to route to PlayerScreen
class SongClickState {
  final String? songId;
  final int clickCount;
  SongClickState({this.songId, this.clickCount = 0});
}

final songClickProvider = StateProvider<SongClickState>((ref) => SongClickState());

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

final searchedSongsProvider = FutureProvider<List<OnlineTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  
  final service = ref.watch(onlineMusicServiceProvider);
  return service.searchSongs(query);
});
