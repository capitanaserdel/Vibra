import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music/main.dart'; // To access the global audioHandler
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music/features/streaming/services/online_music_service.dart';

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return audioHandler.playbackState.stream;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return audioHandler.mediaItem.stream;
});

final playerPositionProvider = StreamProvider<Duration>((ref) {
  return audioHandler.positionStream;
});

final playerDurationProvider = StreamProvider<Duration?>((ref) {
  return audioHandler.durationStream;
});

class PlayerNotifier extends StateNotifier<void> {
  PlayerNotifier() : super(null);

  Future<void> playSong(SongModel song) async {
    final mediaItem = MediaItem(
      id: song.uri ?? song.data,
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: Uri.parse('content://media/external/audio/albumart/${song.albumId}'),
      extras: {'isLocal': true},
    );

    await audioHandler.playFromUri(
      Uri.parse(song.uri ?? song.data),
      {'mediaItem': mediaItem},
    );
  }

  Future<void> playOnlineStation(OnlineStation station) async {
    final mediaItem = MediaItem(
      id: station.url,
      album: 'Online Stream',
      title: station.name,
      artist: station.tags,
      artUri: station.favicon.isNotEmpty ? Uri.parse(station.favicon) : null,
      extras: {'isLocal': false},
    );

    await playMediaItem(mediaItem);
  }

  Future<void> playMediaItem(MediaItem mediaItem) async {
    await audioHandler.playFromUri(
      Uri.parse(mediaItem.id),
      {'mediaItem': mediaItem},
    );
  }

  Future<void> togglePlay() async {
    final playbackState = audioHandler.playbackState.value;
    if (playbackState.playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }
}

final playerNotifierProvider = StateNotifierProvider<PlayerNotifier, void>((ref) {
  return PlayerNotifier();
});
