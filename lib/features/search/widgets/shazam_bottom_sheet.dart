import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audio_service/audio_service.dart';

import 'package:music/core/providers/service_providers.dart';
import 'package:music/features/streaming/services/online_music_service.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/search/screens/search_screen.dart'; // To reuse downloadingTracksProvider

enum ShazamState {
  checkingPermission,
  permissionDenied,
  listening,
  identifying,
  songFound,
  noMatch,
  error
}

class ShazamBottomSheet extends ConsumerStatefulWidget {
  const ShazamBottomSheet({super.key});

  @override
  ConsumerState<ShazamBottomSheet> createState() => _ShazamBottomSheetState();
}

class _ShazamBottomSheetState extends ConsumerState<ShazamBottomSheet>
    with SingleTickerProviderStateMixin {
  ShazamState _state = ShazamState.checkingPermission;
  final _audioRecorder = AudioRecorder();
  AnimationController? _pulseController;
  Timer? _countdownTimer;
  int _secondsRemaining = 6;
  String? _audioPath;
  String _statusText = 'Preparing...';
  String _errorText = '';

  // Identified track metadata
  String? _identifiedTitle;
  String? _identifiedArtist;
  String? _identifiedAlbum;
  String? _identifiedCoverUrl;
  OnlineTrack? _jioTrack;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _checkPermissionAndStart();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndStart() async {
    setState(() {
      _state = ShazamState.checkingPermission;
      _statusText = 'Checking microphone permission...';
    });

    final hasMicPermission = await Permission.microphone.request().isGranted;
    if (!hasMicPermission) {
      setState(() {
        _state = ShazamState.permissionDenied;
        _statusText = 'Microphone permission is required.';
      });
      return;
    }

    _startListening();
  }

  Future<void> _startListening() async {
    try {
      final directory = await getTemporaryDirectory();
      _audioPath = p.join(directory.path, 'shazam_record.m4a');
      final file = File(_audioPath!);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _state = ShazamState.listening;
        _secondsRemaining = 6;
        _statusText = 'Listening to your surroundings...';
      });

      _pulseController?.repeat();

      await _audioRecorder.start(const RecordConfig(), path: _audioPath!);

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining <= 1) {
          _stopAndIdentify();
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    } catch (e) {
      _pulseController?.stop();
      setState(() {
        _state = ShazamState.error;
        _errorText = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopAndIdentify() async {
    _countdownTimer?.cancel();
    _pulseController?.stop();

    setState(() {
      _state = ShazamState.identifying;
      _statusText = 'Analyzing audio print...';
    });

    try {
      final path = await _audioRecorder.stop();
      if (path == null) {
        throw Exception('Audio recording failed.');
      }

      // Read API key from settings box (defaults to 'test')
      final settingsBox = Hive.box('settings_box');
      final apiToken = settingsBox.get('audd_api_token', defaultValue: 'test');

      final request = http.MultipartRequest('POST', Uri.parse('https://api.audd.io/'));
      request.fields['api_token'] = apiToken;
      request.fields['return'] = 'apple_music,spotify';
      request.files.add(await http.MultipartFile.fromPath('file', path));

      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception('Server returned error code ${response.statusCode}');
      }

      final responseBody = await response.stream.bytesToString();
      final jsonResult = json.decode(responseBody);

      if (jsonResult['status'] == 'error') {
        final errorMsg = jsonResult['error']?['error_message'] ?? 'Unknown API error';
        throw Exception(errorMsg);
      }

      if (jsonResult['status'] == 'success' && jsonResult['result'] != null) {
        final result = jsonResult['result'];
        _identifiedTitle = result['title'];
        _identifiedArtist = result['artist'];
        _identifiedAlbum = result['album'];
        
        // Check Spotify or Apple Music cover if available
        if (result['spotify']?['album']?['images'] != null) {
          final images = result['spotify']['album']['images'] as List<dynamic>;
          if (images.isNotEmpty) {
            _identifiedCoverUrl = images[0]['url'];
          }
        }

        // Search JioSaavn API to fetch a full-length track
        setState(() {
          _statusText = 'Searching full track on JioSaavn...';
        });

        final jioService = ref.read(onlineMusicServiceProvider);
        final searchResults = await jioService.searchSongs('$_identifiedArtist $_identifiedTitle');

        if (searchResults.isNotEmpty) {
          _jioTrack = searchResults.first;
        }

        setState(() {
          _state = ShazamState.songFound;
        });
      } else {
        setState(() {
          _state = ShazamState.noMatch;
        });
      }
    } catch (e) {
      setState(() {
        _state = ShazamState.error;
        _errorText = e.toString();
      });
    }
  }

  String _getTrackExtension(OnlineTrack track) {
    try {
      final uri = Uri.parse(track.previewUrl);
      String ext = p.extension(uri.path);
      if (ext == '.mp4') return '.m4a';
      return ext.isNotEmpty ? ext : '.mp3';
    } catch (_) {
      return '.mp3';
    }
  }

  Future<bool> _isTrackDownloaded(OnlineTrack track) async {
    try {
      final fileService = ref.read(fileManagementServiceProvider);
      final outputDir = await fileService.getDownloadDirectory();
      if (outputDir == null) return false;
      final sanitizedTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final sanitizedArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      final legacyFile = File(p.join(outputDir.path, '${sanitizedTitle}_$sanitizedArtist.mp3'));
      if (await legacyFile.exists()) return true;

      final ext = _getTrackExtension(track);
      if (ext != '.mp3') {
        final correctFile = File(p.join(outputDir.path, '${sanitizedTitle}_$sanitizedArtist$ext'));
        if (await correctFile.exists()) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _downloadTrack(OnlineTrack track) async {
    final fileService = ref.read(fileManagementServiceProvider);
    final outputDir = await fileService.getDownloadDirectory();
    if (outputDir == null) return;
    
    // Quick Android permission request helper inside BottomSheet
    if (Platform.isAndroid) {
      final hasPermission = await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted;
      if (!hasPermission) {
        final granted = await Permission.storage.request().isGranted || await Permission.manageExternalStorage.request().isGranted;
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission required to download.')),
            );
          }
          return;
        }
      }
    }

    final notifier = ref.read(downloadingTracksProvider.notifier);
    notifier.setProgress(track.id, 0.0);
    setState(() {}); // Force rebuild of download button state

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(track.previewUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Server returned status code ${response.statusCode}");
      }

      final contentLength = response.contentLength ?? 0;
      
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final sanitizedTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final sanitizedArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final ext = _getTrackExtension(track);
      final filename = '${sanitizedTitle}_$sanitizedArtist$ext';
      final file = File(p.join(outputDir.path, filename));
      final sink = file.openWrite();

      int downloaded = 0;
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          final progress = downloaded / contentLength;
          notifier.setProgress(track.id, progress);
        }
      });

      await sink.close();
      client.close();

      // Index in MediaStore
      final onAudioQuery = OnAudioQuery();
      await onAudioQuery.scanMedia(file.path);

      // Invalidate providers
      ref.invalidate(localSongsProvider);
      notifier.completeDownload(track.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "${track.title}" successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      notifier.completeDownload(track.id);
      print("Download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download "${track.title}": $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.surface.withOpacity(0.92),
          theme.colorScheme.onSurface.withOpacity(0.03),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Music Identifier',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          _buildContent(theme, mediaItem, playbackState),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, MediaItem? mediaItem, PlaybackState? playbackState) {
    switch (_state) {
      case ShazamState.checkingPermission:
      case ShazamState.identifying:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );

      case ShazamState.permissionDenied:
        return Column(
          children: [
            Icon(Icons.mic_off_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkPermissionAndStart,
              child: const Text('Grant Permission'),
            ),
            const SizedBox(height: 20),
          ],
        );

      case ShazamState.listening:
        return Column(
          children: [
            // Pulse wave circle animation
            AnimatedBuilder(
              animation: _pulseController!,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple
                    Container(
                      width: 120 * (1.0 + _pulseController!.value * 0.3),
                      height: 120 * (1.0 + _pulseController!.value * 0.3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12 * (1.0 - _pulseController!.value)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Inner ripple
                    Container(
                      width: 100 * (1.0 + _pulseController!.value * 0.2),
                      height: 100 * (1.0 + _pulseController!.value * 0.2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.24 * (1.0 - _pulseController!.value)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Pulsing main circle
                    GestureDetector(
                      onTap: _stopAndIdentify,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              _statusText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recording... $_secondsRemaining seconds remaining',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );

      case ShazamState.songFound:
        final track = _jioTrack;
        final coverUrl = track?.coverUrl ?? _identifiedCoverUrl;
        final title = track?.title ?? _identifiedTitle ?? 'Unknown Song';
        final artist = track?.artist ?? _identifiedArtist ?? 'Unknown Artist';
        final album = track?.album ?? _identifiedAlbum ?? 'Unknown Album';

        final isCurrentTrack = track != null && mediaItem != null && mediaItem.id == track.previewUrl;
        final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);
        final isLoading = isCurrentTrack && (playbackState?.processingState == AudioProcessingState.buffering || playbackState?.processingState == AudioProcessingState.loading);

        return Column(
          children: [
            // Artwork display with shadow
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultCover(theme),
                      )
                    : _buildDefaultCover(theme),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (track?.isPreviewOnly ?? false) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '30s Preview Only',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '$artist • $album',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            if (track != null) ...[
              // Play & Download actions if JioSaavn match was found
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play button
                  _buildPlayButton(theme, track, isCurrentTrack, isPlaying, isLoading),
                  const SizedBox(width: 24),
                  // Download button
                  _buildDownloadAction(theme, track),
                ],
              ),
            ] else ...[
              // JioSaavn match failed, but AudD recognized it
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Song identified, but not available for streaming or download in local catalog.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _startListening,
                  child: const Text('Identify Another'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        );

      case ShazamState.noMatch:
        return Column(
          children: [
            Icon(
              Icons.music_off_outlined,
              size: 64,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Song Identified',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Make sure the music is playing loud and clear, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startListening,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );

      case ShazamState.error:
        return Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Identification Error',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorText.contains('test token') || _errorText.contains('credits') || _errorText.contains('api_token')
                    ? 'AudD API token limit reached. Please set/upgrade your AudD token in settings.'
                    : 'Error: $_errorText',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startListening,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
    }
  }

  Widget _buildDefaultCover(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withOpacity(0.2),
      child: Icon(
        Icons.music_note_rounded,
        size: 64,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildPlayButton(ThemeData theme, OnlineTrack track, bool isCurrentTrack, bool isPlaying, bool isLoading) {
    if (isLoading) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 32,
          color: Colors.white,
        ),
        onPressed: () {
          if (isCurrentTrack) {
            ref.read(playerNotifierProvider.notifier).togglePlay();
          } else {
            ref.read(playerNotifierProvider.notifier).playOnlineTrack(track);
          }
          setState(() {});
        },
      ),
    );
  }

  Widget _buildDownloadAction(ThemeData theme, OnlineTrack track) {
    if (track.isPreviewOnly) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.04),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
        ),
        child: IconButton(
          icon: Icon(
            Icons.download_for_offline_rounded,
            size: 28,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Downloading is disabled for preview-only tracks.'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
      );
    }

    final downloadProgress = ref.watch(downloadingTracksProvider)[track.id];
    final isDownloading = downloadProgress != null;

    if (isDownloading) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          value: downloadProgress > 0 ? downloadProgress : null,
          strokeWidth: 3,
          color: theme.colorScheme.primary,
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _isTrackDownloaded(track),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        if (isDownloaded) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.green.shade50.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade400,
              size: 28,
            ),
          );
        }

        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.12)),
          ),
          child: IconButton(
            icon: Icon(
              Icons.download_for_offline_rounded,
              size: 28,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: () => _downloadTrack(track),
          ),
        );
      },
    );
  }
}
