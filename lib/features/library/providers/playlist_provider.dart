import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A playlist is stored in Hive under 'playlist_box' as:
/// key   = playlist name (String)
/// value = List<String> of song IDs (uri or data paths)

class PlaylistNotifier extends StateNotifier<List<String>> {
  final Box _box = Hive.box('playlist_box');

  PlaylistNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = _box.keys.cast<String>().toList();
  }

  List<String> getPlaylistSongs(String name) {
    final val = _box.get(name);
    if (val is List) return val.cast<String>();
    return [];
  }

  void createPlaylist(String name) {
    if (_box.containsKey(name)) return;
    _box.put(name, <String>[]);
    _load();
  }

  void deletePlaylist(String name) {
    _box.delete(name);
    _load();
  }

  void addSongToPlaylist(String playlistName, String songId) {
    final songs = getPlaylistSongs(playlistName);
    if (!songs.contains(songId)) {
      songs.add(songId);
      _box.put(playlistName, songs);
      _load();
    }
  }

  void removeSongFromPlaylist(String playlistName, String songId) {
    final songs = getPlaylistSongs(playlistName);
    songs.remove(songId);
    _box.put(playlistName, songs);
    _load();
  }

  bool containsSong(String playlistName, String songId) {
    return getPlaylistSongs(playlistName).contains(songId);
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, List<String>>(
  (_) => PlaylistNotifier(),
);
