import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  /// Latest Android audio session ID — null on non-Android or until first playback
  int? audioSessionId;

  MusicAudioHandler() {
    // Broadcast state changes
    _player.playbackEventStream.map(_transformEvent).listen(playbackState.add);

    // Listen to current processing state to handle completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
    // Set default repeat mode to ALL as requested
    _player.setLoopMode(LoopMode.all);

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

    // Track audio session ID for equalizer use
    _player.androidAudioSessionIdStream.listen((id) {
      audioSessionId = id;
      if (id != null && id != 0) {
        _applyEqualizerSettings(id);
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

    // Load Shuffle Mode
    final savedShuffleIndex = box.get('shuffle_mode');
    if (savedShuffleIndex != null) {
      final shuffleMode = AudioServiceShuffleMode.values[savedShuffleIndex as int];
      final enabled = shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group;
      _player.setShuffleModeEnabled(enabled);
    }

    // Load Repeat Mode
    final savedRepeatIndex = box.get('repeat_mode');
    if (savedRepeatIndex != null) {
      final repeatMode = AudioServiceRepeatMode.values[savedRepeatIndex as int];
      final loopMode = {
        AudioServiceRepeatMode.none: LoopMode.off,
        AudioServiceRepeatMode.one: LoopMode.one,
        AudioServiceRepeatMode.all: LoopMode.all,
      }[repeatMode]!;
      _player.setLoopMode(loopMode);
    } else {
      _player.setLoopMode(LoopMode.all);
    }

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

  Future<void> _applyEqualizerSettings(int sessionId) async {
    const channel = MethodChannel('com.example.vibra/file_management');
    try {
      final result = await channel.invokeMethod<Map>('equalizerInit', {
        'audioSessionId': sessionId,
      });
      if (result != null) {
        final rawBands = (result['bands'] as List).cast<Map>();
        final box = Hive.box('settings_box');
        for (final b in rawBands) {
          final index = (b['index'] as num).toInt();
          final saved = box.get('eq_band_$index');
          if (saved != null) {
            await channel.invokeMethod('equalizerSetBandLevel', {
              'band': index,
              'level': saved as int,
            });
          }
        }
        final savedEnabled = box.get('eq_enabled', defaultValue: true) as bool;
        await channel.invokeMethod('equalizerSetEnabled', {'enabled': savedEnabled});
      }
    } catch (e) {
      print("Error applying equalizer settings in audio handler: $e");
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
      final item = extras?['mediaItem'] as MediaItem?;
      if (item != null) {
        mediaItem.add(item);
        // Also add to queue so the queue view is never empty for single-song plays
        queue.add([item]);
      }
      await _player.setAudioSource(_createAudioSource(uri.toString()));
      play();
    } catch (e) {
      print("Error playing from URI: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event, {AudioServiceShuffleMode? shuffleOverride, AudioServiceRepeatMode? repeatOverride}) {
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
      shuffleMode: shuffleOverride ?? (_player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none),
      repeatMode: repeatOverride ?? {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
    );
  }

  void _broadcastState({AudioServiceShuffleMode? shuffleOverride, AudioServiceRepeatMode? repeatOverride}) {
    playbackState.add(_transformEvent(
      PlaybackEvent(
        processingState: _player.processingState,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ),
      shuffleOverride: shuffleOverride,
      repeatOverride: repeatOverride,
    ));
  }

  // Stream current position for UI updates
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // PRD: Shuffle & Repeat
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all || mode == AudioServiceShuffleMode.group;
    _player.setShuffleModeEnabled(enabled);
    _broadcastState(shuffleOverride: mode);
    Hive.box('settings_box').put('shuffle_mode', mode.index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    final loopMode = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[mode]!;
    _player.setLoopMode(loopMode);
    _broadcastState(repeatOverride: mode);
    Hive.box('settings_box').put('repeat_mode', mode.index);
  }

  Future<void> cycleRepeatMode() async {
    final currentMode = playbackState.value.repeatMode;
    final nextMode = {
      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
    }[currentMode]!;
    
    await setRepeatMode(nextMode);
  }
}
