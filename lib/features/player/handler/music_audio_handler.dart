import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MusicAudioHandler() {
    // Broadcast state changes
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen to current processing state to handle completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });

    // Persistent Session Logic
    _player.positionStream.listen((pos) {
      if (_player.playing) {
        Hive.box('settings_box').put('last_position', pos.inMilliseconds);
      }
      // Broadcast current state to ensure position is captured
      _broadcastState();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    mediaItem.listen((item) {
      if (item != null) {
        final itemMap = {
          'id': item.id,
          'title': item.title,
          'artist': item.artist,
          'album': item.album,
          'duration': item.duration?.inMilliseconds,
          'artUri': item.artUri?.toString(),
        };
        Hive.box('settings_box').put('last_media_item', json.encode(itemMap));
        
        // Log to play history
        Hive.box('play_history_box').add({
          'songId': item.id,
          'playedAt': DateTime.now().toIso8601String(),
          'moment': null, // Future: detect current moment
        });
      }
    });

    _loadSession();
  }

  Future<void> _loadSession() async {
    final box = Hive.box('settings_box');
    final lastItemJson = box.get('last_media_item');
    final lastPos = box.get('last_position', defaultValue: 0);

    if (lastItemJson != null) {
      final map = json.decode(lastItemJson);
      final item = MediaItem(
        id: map['id'],
        title: map['title'],
        artist: map['artist'],
        album: map['album'],
        duration: Duration(milliseconds: map['duration'] ?? 0),
        artUri: map['artUri'] != null ? Uri.parse(map['artUri']) : null,
      );
      mediaItem.add(item);
      await _player.setAudioSource(_createAudioSource(item.id));
      await _player.seek(Duration(milliseconds: lastPos));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems, {int initialIndex = 0}) async {
    final audioSource = ConcatenatingAudioSource(
      children: mediaItems.map((item) => _createAudioSource(item.id)).toList(),
    );
    queue.add(mediaItems);
    await _player.setAudioSource(audioSource, initialIndex: initialIndex);
  }

  AudioSource _createAudioSource(String id) {
    if (id.startsWith('content://') || id.startsWith('http')) {
      return AudioSource.uri(Uri.parse(id));
    }
    return AudioSource.uri(Uri.file(id));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    try {
      final mediaItem = extras?['mediaItem'] as MediaItem?;
      if (mediaItem != null) {
        this.mediaItem.add(mediaItem);
      }
      
      await _player.setAudioSource(_createAudioSource(uri.toString()));
      play();
    } catch (e) {
      print("Error playing from URI: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      shuffleMode: _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
    );
  }

  void _broadcastState() {
    playbackState.add(_transformEvent(PlaybackEvent(
      processingState: _player.processingState,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
    )));
  }

  // Stream current position for UI updates
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // PRD: Shuffle & Repeat
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all || mode == AudioServiceShuffleMode.group;
    await _player.setShuffleModeEnabled(enabled);
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    final loopMode = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[mode]!;
    await _player.setLoopMode(loopMode);
    _broadcastState();
  }
}
