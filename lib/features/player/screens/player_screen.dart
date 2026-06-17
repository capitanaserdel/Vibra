import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:music/main.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/player/widgets/circular_progress_ring.dart';
import 'package:music/features/player/widgets/lyrics_view.dart';
import 'package:music/features/player/widgets/track_carousel.dart';
import 'package:music/features/player/widgets/linear_player.dart';
import 'package:music/features/library/providers/playlist_provider.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:music/features/player/screens/equalizer_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';


class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    setState(() => _sleepRemaining = duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final newRemaining = _sleepRemaining! - const Duration(seconds: 1);
      if (newRemaining <= Duration.zero) {
        t.cancel();
        setState(() => _sleepRemaining = null);
        ref.read(playerNotifierProvider.notifier).togglePlay();
      } else {
        setState(() => _sleepRemaining = newRemaining);
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() { _sleepTimer = null; _sleepRemaining = null; });
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final duration = mediaItem?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0 
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isLinearStyle = settings.playerStyle == 'Linear';

    if (mediaItem == null) return const Scaffold();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          // 1. Dynamic Background (Blur for Dark, Gradient for Light)
          _buildBackground(context, mediaItem.artUri?.toString(), mediaItem),

          SafeArea(
            child: Column(
              children: [
                // 2. Navigation Header
                _buildTopTabs(context),

                Expanded(
                  child: _showLyrics
                      ? Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: LyricsView(mediaItem: mediaItem),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 7. Main Control Row (Fixed at bottom on lyrics page)
                            _buildMainControls(context, playbackState?.playing ?? false),
                            const SizedBox(height: 20),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              
                              // 3. Main Player (Circular / Linear)
                              GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity! < 0) {
                                    ref.read(playerNotifierProvider.notifier).skipToNext();
                                  } else if (details.primaryVelocity! > 0) {
                                    ref.read(playerNotifierProvider.notifier).skipToPrevious();
                                  }
                                },
                                child: isLinearStyle 
                                    ? const LinearPlayer() 
                                    : _buildCircularPlayer(context, mediaItem.artUri?.toString(), progress, position),
                              ),

                              const SizedBox(height: 20),

                              // 4. Song Info
                              _buildSongInfo(context, mediaItem.title, mediaItem.artist ?? 'Unknown Artist'),

                              const SizedBox(height: 10),

                              // 5. Mandatory Linear Seek Bar (Phase 9 requirement)
                              //_buildLinearSeekBar(context, position, duration),

                              const SizedBox(height: 20),

                              // 6. Secondary Control Row
                              _buildSecondaryControls(context),

                              const SizedBox(height: 25),

                              // 7. Main Control Row
                              _buildMainControls(context, playbackState?.playing ?? false),
                              
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),

                // 8. Bottom Track Carousel
                _buildBottomCarousel(context, mediaItem.id),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _parseAlbumId(String? imageUrl) {
    if (imageUrl == null) return null;
    if (imageUrl.contains('albumart/')) {
      return int.tryParse(imageUrl.split('albumart/').last);
    }
    return int.tryParse(imageUrl);
  }

  Future<void> _changeSongArtwork(MediaItem mediaItem) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'custom_art_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(picked.path).copy('${appDir.path}/$fileName');

      final metadataBox = Hive.box('metadata_box');
      final current = metadataBox.get(mediaItem.id);
      final existing = (current is Map) ? Map<String, dynamic>.from(current) : <String, dynamic>{};
      existing['customArtworkPath'] = savedFile.path;
      await metadataBox.put(mediaItem.id, existing);

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Song artwork updated successfully!'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _removeSongArtwork(MediaItem mediaItem) async {
    final metadataBox = Hive.box('metadata_box');
    final current = metadataBox.get(mediaItem.id);
    if (current is Map) {
      final existing = Map<String, dynamic>.from(current);
      existing.remove('customArtworkPath');
      await metadataBox.put(mediaItem.id, existing);
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Custom artwork removed.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildPlayerArtwork(String? imageUrl, MediaItem mediaItem, {double borderRadius = 20}) {
    final metadataBox = Hive.box('metadata_box');
    final meta = metadataBox.get(mediaItem.id);
    final customArtPath = (meta is Map) ? meta['customArtworkPath'] as String? : null;
    final hasCustomArt = customArtPath != null && customArtPath.isNotEmpty && File(customArtPath).existsSync();

    final isNetwork = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    final albumId = _parseAlbumId(imageUrl);

    Widget artwork;
    if (hasCustomArt) {
      artwork = Image.file(File(customArtPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (isNetwork) {
      artwork = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset('assets/images/default_album_art.png', fit: BoxFit.cover),
      );
    } else if (albumId != null && albumId != 0) {
      artwork = QueryArtworkWidget(
        id: albumId,
        type: ArtworkType.ALBUM,
        artworkWidth: double.infinity,
        artworkHeight: double.infinity,
        artworkFit: BoxFit.cover,
        nullArtworkWidget: Image.asset('assets/images/default_album_art.png', fit: BoxFit.cover),
      );
    } else {
      artwork = Image.asset('assets/images/default_album_art.png', fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: artwork,
    );
  }

  Widget _buildBackground(BuildContext context, String? imageUrl, MediaItem mediaItem) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final settings = ref.watch(settingsProvider);
    final playerTheme = settings.playerTheme;

    // ── Light mode: always solid gradient ──────────────────────
    if (isLight) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
          ),
        ),
      );
    }

    // ── Solid: just an accent-color gradient ───────────────────
    if (playerTheme == 'Solid') {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.25),
              theme.colorScheme.background,
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
      );
    }

    // ── Image: user-picked custom image ───────────────────────
    if (playerTheme == 'Image') {
      final imgPath = settings.playerBackgroundImagePath;
      final hasImg = imgPath.isNotEmpty && File(imgPath).existsSync();
      return Stack(
        children: [
          Positioned.fill(
            child: hasImg
                ? Image.file(File(imgPath), fit: BoxFit.cover, gaplessPlayback: true)
                : Container(color: theme.colorScheme.background),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: settings.playerBackgroundBlur,
              sigmaY: settings.playerBackgroundBlur,
            ),
            child: Container(
              color: theme.brightness == Brightness.light
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.35),
            ),
          ),
        ],
      );
    }

    // ── Dynamic (default): blurred album art ──────────────────
    final metadataBox = Hive.box('metadata_box');
    final meta = metadataBox.get(mediaItem.id);
    final customArtPath = (meta is Map) ? meta['customArtworkPath'] as String? : null;
    final hasCustomArt = customArtPath != null && customArtPath.isNotEmpty && File(customArtPath).existsSync();

    final isNetwork = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    final albumId = _parseAlbumId(imageUrl);
    final hasSystemArt = isNetwork || (albumId != null && albumId != 0);

    Widget? artworkLayer;
    if (hasCustomArt) {
      artworkLayer = Image.file(File(customArtPath), fit: BoxFit.cover);
    } else if (isNetwork) {
      artworkLayer = Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else if (hasSystemArt) {
      artworkLayer = QueryArtworkWidget(
        id: albumId!,
        type: ArtworkType.ALBUM,
        artworkWidth: double.infinity,
        artworkHeight: double.infinity,
        artworkFit: BoxFit.cover,
        nullArtworkWidget: const SizedBox.shrink(),
      );
    }

    if (artworkLayer != null) {
      return Stack(
        children: [
          Positioned.fill(child: artworkLayer),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  theme.colorScheme.background,
                ],
              ),
            ),
          ),
        ],
      );
    }

    // If there is NO artwork (custom or system), leave the app's own custom wallpaper image on!
    final appBgPath = settings.appBackgroundImagePath;
    final hasAppBg = appBgPath.isNotEmpty && File(appBgPath).existsSync();
    if (hasAppBg) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.file(File(appBgPath), fit: BoxFit.cover),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: settings.appBackgroundBlur,
              sigmaY: settings.appBackgroundBlur,
            ),
            child: Container(
              color: theme.brightness == Brightness.light
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
          ),
        ],
      );
    }

    // Default dark fallback gradient
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.25),
            theme.colorScheme.background,
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: theme.colorScheme.onBackground),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onBackground.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabItem(context, "Song", !_showLyrics, () => setState(() => _showLyrics = false)),
                Container(width: 1, height: 12, color: theme.colorScheme.onBackground.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 8)),
                _buildTabItem(context, "Lyrics", _showLyrics, () => setState(() => _showLyrics = true)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onBackground),
            onPressed: () => _showPlayerSettingsBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: active ? theme.colorScheme.onBackground : theme.colorScheme.onBackground.withOpacity(0.4),
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCircularPlayer(BuildContext context, String? imageUrl, double progress, Duration position) {
    final theme = Theme.of(context);
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final duration = mediaItem?.duration ?? Duration.zero;

    return Center(
      child: CircularProgressRing(
        progress: progress,
        size: MediaQuery.of(context).size.width * 0.75,
        progressColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.onBackground.withOpacity(0.05),
        onSeek: (newProgress) {
          if (duration.inMilliseconds > 0) {
            final targetMs = (duration.inMilliseconds * newProgress).toInt();
            ref.read(playerNotifierProvider.notifier).seek(Duration(milliseconds: targetMs));
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Artwork
            _buildPlayerArtwork(imageUrl, mediaItem!),
            
            // Time Overlay
            Container(
              color: theme.brightness == Brightness.dark ? Colors.black38 : Colors.white24,
              child: Center(
                child: Text(
                  _formatDuration(position),
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, String title, String artist) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: MarqueeText(
        textSpan: TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
              ),
            ),
            TextSpan(
              text: '   •   ',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onBackground.withOpacity(0.4),
              ),
            ),
            TextSpan(
              text: artist,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onBackground.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        velocity: 30.0,
        gap: 80.0,
      ),
    );
  }

  Widget _buildLinearSeekBar(BuildContext context, Duration position, Duration duration) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds > 0 
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Slider(
            value: progress,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.primary.withOpacity(0.1),
            onChanged: (val) {
              final targetMs = (duration.inMilliseconds * val).toInt();
              ref.read(playerNotifierProvider.notifier).seek(Duration(milliseconds: targetMs));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground.withOpacity(0.6))),
                Text(_formatDuration(duration), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground.withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryControls(BuildContext context) {
    final theme = Theme.of(context);
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    if (mediaItem == null) return const SizedBox.shrink();

    // --- Favorite state from Hive ---
    final metadataBox = Hive.box('metadata_box');
    final meta = metadataBox.get(mediaItem.id);
    final isFavorite = (meta is Map && meta['isFavorite'] == true);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Favorite
        IconButton(
          tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite
                ? theme.colorScheme.primary
                : theme.colorScheme.onBackground.withOpacity(0.7),
            size: 24,
          ),
          onPressed: () {
            final current = metadataBox.get(mediaItem.id);
            final existing = (current is Map) ? Map<String, dynamic>.from(current) : <String, dynamic>{};
            existing['isFavorite'] = !isFavorite;
            metadataBox.put(mediaItem.id, existing);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isFavorite ? 'Removed from Favorites' : 'Added to Favorites'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          },
        ),

        // Sleep Timer
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              tooltip: _sleepRemaining != null ? 'Cancel Sleep Timer' : 'Sleep Timer',
              icon: Icon(
                Icons.alarm_rounded,
                color: _sleepRemaining != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onBackground.withOpacity(0.7),
                size: 24,
              ),
              onPressed: () => _sleepRemaining != null
                  ? _showCancelTimerDialog(context)
                  : _showSleepTimerDialog(context),
            ),
            if (_sleepRemaining != null)
              Positioned(
                top: 6,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_sleepRemaining!.inMinutes}:${(_sleepRemaining!.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Add to Playlist
        IconButton(
          tooltip: 'Add to Playlist',
          icon: Icon(Icons.playlist_add_rounded,
              color: theme.colorScheme.onBackground.withOpacity(0.7), size: 24),
          onPressed: () => _showAddToPlaylistDialog(context, mediaItem),
        ),

        // Queue
        IconButton(
          tooltip: 'View Queue',
          icon: Icon(Icons.queue_music_rounded,
              color: theme.colorScheme.onBackground.withOpacity(0.7), size: 24),
          onPressed: () => _showQueueBottomSheet(context),
        ),

        // Equalizer
        IconButton(
          tooltip: 'Equalizer',
          icon: Icon(Icons.tune_rounded,
              color: theme.colorScheme.onBackground.withOpacity(0.7), size: 24),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EqualizerScreen()),
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MediaItem mediaItem) {
    final songId = mediaItem.id;
    final playlists = ref.read(playlistProvider);
    final newPlaylistController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final latestPlaylists = ref.read(playlistProvider);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add to Playlist', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // Create new playlist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newPlaylistController,
                          decoration: const InputDecoration(
                            hintText: 'New playlist name...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final name = newPlaylistController.text.trim();
                          if (name.isEmpty) return;
                          ref.read(playlistProvider.notifier).createPlaylist(name);
                          ref.read(playlistProvider.notifier).addSongToPlaylist(name, songId);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Added to new playlist "$name"'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ),
                if (latestPlaylists.isNotEmpty) ...[  
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Align(alignment: Alignment.centerLeft,
                        child: Text('Existing Playlists', style: theme.textTheme.labelMedium)),
                  ),
                  ...latestPlaylists.map((name) {
                    final alreadyIn = ref.read(playlistProvider.notifier).containsSong(name, songId);
                    return ListTile(
                      leading: Icon(Icons.queue_music_rounded, color: theme.colorScheme.primary),
                      title: Text(name),
                      trailing: alreadyIn
                          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        if (!alreadyIn) {
                          ref.read(playlistProvider.notifier).addSongToPlaylist(name, songId);
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(alreadyIn ? 'Already in "$name"' : 'Added to "$name"'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                    );
                  }),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    final options = [
      ('5 min', const Duration(minutes: 5)),
      ('15 min', const Duration(minutes: 15)),
      ('30 min', const Duration(minutes: 30)),
      ('45 min', const Duration(minutes: 45)),
      ('1 hour', const Duration(hours: 1)),
      ('2 hours', const Duration(hours: 2)),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sleep Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) => ListTile(
            leading: const Icon(Icons.alarm_rounded),
            title: Text(opt.$1),
            onTap: () {
              Navigator.pop(ctx);
              _startSleepTimer(opt.$2);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Sleep timer set for ${opt.$1}'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))
        ],
      ),
    );
  }

  void _showCancelTimerDialog(BuildContext context) {
    final mins = _sleepRemaining!.inMinutes;
    final secs = (_sleepRemaining!.inSeconds % 60).toString().padLeft(2, '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sleep Timer Active'),
        content: Text('Playback will stop in $mins:$secs. Cancel the timer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _cancelSleepTimer(); },
            child: const Text('Cancel Timer'),
          ),
        ],
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StreamBuilder<List<MediaItem>>(
        stream: audioHandler.queue,
        initialData: audioHandler.queue.value,
        builder: (ctx, queueSnap) {
          return StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            initialData: audioHandler.mediaItem.value,
            builder: (ctx, itemSnap) {
              final queue = queueSnap.data ?? [];
              final currentId = itemSnap.data?.id;
              if (queue.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Queue is empty')),
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Queue (${queue.length})',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (_, i) {
                        final item = queue[i];
                        final isCurrent = item.id == currentId;
                        return ListTile(
                          leading: Icon(
                            Icons.music_note_rounded,
                            color: isCurrent
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            item.artist ?? 'Unknown Artist',
                            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                          ),
                          trailing: isCurrent
                              ? Icon(Icons.equalizer_rounded, color: Theme.of(ctx).colorScheme.primary)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            audioHandler.skipToQueueItem(i);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMainControls(BuildContext context, bool isPlaying) {
    final theme = Theme.of(context);
    final playbackState = ref.watch(playbackStateProvider).value;
    final isShuffle = playbackState?.shuffleMode == AudioServiceShuffleMode.all;
    final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

    IconData repeatIcon = Icons.repeat_rounded;
    if (repeatMode == AudioServiceRepeatMode.one) repeatIcon = Icons.repeat_one_rounded;
    final isRepeatActive = repeatMode != AudioServiceRepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded, 
            size: 24, 
            color: isShuffle ? theme.colorScheme.primary : theme.colorScheme.onBackground.withOpacity(0.4)
          ), 
          onPressed: () => ref.read(playerNotifierProvider.notifier).toggleShuffle(),
        ),
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, size: 48, color: theme.colorScheme.onBackground), 
          onPressed: () => ref.read(playerNotifierProvider.notifier).skipToPrevious(),
        ),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 44,
              color: theme.colorScheme.onPrimary,
            ),
            onPressed: () => ref.read(playerNotifierProvider.notifier).togglePlay(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, size: 48, color: theme.colorScheme.onBackground), 
          onPressed: () => ref.read(playerNotifierProvider.notifier).skipToNext(),
        ),
        IconButton(
          icon: Icon(
            repeatIcon, 
            size: 24, 
            color: isRepeatActive ? theme.colorScheme.primary : theme.colorScheme.onBackground.withOpacity(0.4)
          ), 
          onPressed: () => ref.read(playerNotifierProvider.notifier).cycleRepeatMode(),
        ),
      ],
    );
  }

  Widget _buildBottomCarousel(BuildContext context, String currentTrackId) {
    final theme = Theme.of(context);
    
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      initialData: audioHandler.queue.value,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        final currentIndex = queue.indexWhere((item) => item.id == currentTrackId);
        final displayedTracks = currentIndex != -1 && currentIndex + 1 < queue.length
            ? queue.sublist(currentIndex + 1)
            : <MediaItem>[];

        if (displayedTracks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                "Up Next",
                style: TextStyle(
                  color: theme.colorScheme.onBackground.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            TrackCarousel(
              tracks: displayedTracks,
              currentTrackId: currentTrackId,
              onTrackTap: (track) {
                final targetIndex = queue.indexWhere((item) => item.id == track.id);
                if (targetIndex != -1) {
                  audioHandler.skipToQueueItem(targetIndex);
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showPlayerSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final mediaItem = ref.watch(currentMediaItemProvider).value;
            if (mediaItem == null) return const SizedBox.shrink();

            final theme = Theme.of(context);
            final settings = ref.watch(settingsProvider);
            final settingsNotifier = ref.read(settingsProvider.notifier);
            
            final currentTheme = settings.playerTheme;
            final options = ['Dynamic', 'Solid', 'Image'];
            final icons = [Icons.auto_awesome_rounded, Icons.gradient_rounded, Icons.image_rounded];
            final hasPlayerImage = settings.playerBackgroundImagePath.isNotEmpty &&
                File(settings.playerBackgroundImagePath).existsSync();

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Player Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Player Theme Label
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Player Background Theme',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Player Theme Selector Segmented Chips
                      Row(
                        children: List.generate(options.length, (i) {
                          final opt = options[i];
                          final isSelected = currentTheme == opt;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
                              child: GestureDetector(
                                onTap: () => settingsNotifier.setPlayerTheme(opt),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icons[i],
                                        size: 20,
                                        color: isSelected
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        opt,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Player Style Label
                      Row(
                        children: [
                          Icon(Icons.aspect_ratio_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Player Layout Style',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Player Style Selector Segmented Chips
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => settingsNotifier.setPlayerStyle('Circle'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: settings.playerStyle == 'Circle'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: settings.playerStyle == 'Circle'
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle_outlined,
                                        size: 20,
                                        color: settings.playerStyle == 'Circle'
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Circular Player',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: settings.playerStyle == 'Circle'
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => settingsNotifier.setPlayerStyle('Linear'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: settings.playerStyle == 'Linear'
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: settings.playerStyle == 'Linear'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reorder_rounded,
                                      size: 20,
                                      color: settings.playerStyle == 'Linear'
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Linear Player',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: settings.playerStyle == 'Linear'
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Image picker (only visible if Theme == 'Image')
                      if (currentTheme == 'Image') ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              settingsNotifier.setPlayerBackgroundImagePath(picked.path);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasPlayerImage
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(0.3),
                                width: hasPlayerImage ? 2 : 1,
                              ),
                              image: hasPlayerImage
                                  ? DecorationImage(
                                      image: FileImage(File(settings.playerBackgroundImagePath)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: hasPlayerImage ? null : theme.colorScheme.onSurface.withOpacity(0.04),
                            ),
                            child: hasPlayerImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.4),
                                      child: Center(
                                        child: Text(
                                          'Change Player Image',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 28, color: theme.colorScheme.primary),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Choose Player Background',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        if (hasPlayerImage) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.blur_on_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 8),
                              Text(
                                'Blur Intensity: ${settings.playerBackgroundBlur.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: settings.playerBackgroundBlur,
                              min: 0.0,
                              max: 20.0,
                              onChanged: settingsNotifier.setPlayerBackgroundBlur,
                            ),
                          ),
                        ],
                      ],
                      
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Song Artwork Customization
                      Row(
                        children: [
                          Icon(Icons.photo_library_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Song Artwork',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary),
                        title: const Text('Change Song Artwork'),
                        subtitle: const Text('Pick a custom image for this song'),
                        onTap: () {
                          Navigator.pop(context);
                          _changeSongArtwork(mediaItem);
                        },
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final metadataBox = Hive.box('metadata_box');
                          final meta = metadataBox.get(mediaItem.id);
                          final customArtPath = (meta is Map) ? meta['customArtworkPath'] as String? : null;
                          final hasCustomArt = customArtPath != null && customArtPath.isNotEmpty && File(customArtPath).existsSync();
                          if (!hasCustomArt) return const SizedBox.shrink();
                          return ListTile(
                            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            title: const Text('Remove Custom Artwork', style: TextStyle(color: Colors.redAccent)),
                            subtitle: const Text('Restore system default artwork'),
                            onTap: () {
                              Navigator.pop(context);
                              _removeSongArtwork(mediaItem);
                            },
                          );
                        },
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Quick Settings Shortcuts
                      ListTile(
                        leading: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                        title: const Text('Sound Equalizer'),
                        subtitle: const Text('Adjust frequency bands and presets'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                          );
                        },
                      ),
                      
                      ListTile(
                        leading: Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                        title: const Text('Sleep Timer'),
                        subtitle: Text(
                          _sleepRemaining != null 
                              ? 'Remaining: ${_formatDuration(_sleepRemaining!)}' 
                              : 'Set a timer to automatically pause playback'
                        ),
                        trailing: _sleepRemaining != null 
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  _cancelSleepTimer();
                                  Navigator.pop(context);
                                },
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _sleepRemaining != null 
                            ? null
                            : () {
                                Navigator.pop(context);
                                _showSleepTimerDialog(context);
                              },
                      ),
                      
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MarqueeText extends StatefulWidget {
  final InlineSpan textSpan;
  final double velocity; // Pixels per second
  final double gap;

  const MarqueeText({
    Key? key,
    required this.textSpan,
    this.velocity = 30.0,
    this.gap = 80.0,
  }) : super(key: key);

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  bool _shouldScroll = false;
  double _textWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupMarquee());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textSpan.toPlainText() != widget.textSpan.toPlainText()) {
      _resetMarquee();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetMarquee() {
    _shouldScroll = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupMarquee());
  }

  void _setupMarquee() {
    if (!mounted) return;
    
    final textPainter = TextPainter(
      text: widget.textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    _textWidth = textPainter.width;
    final screenWidth = MediaQuery.of(context).size.width - 48; // Padding 24 on each side

    if (_textWidth > screenWidth) {
      setState(() {
        _shouldScroll = true;
      });
      // Defer execution of _animate until after the build frame renders the ListView.builder
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animate();
      });
    } else {
      setState(() {
        _shouldScroll = false;
      });
    }
  }

  void _animate() async {
    if (!mounted || !_shouldScroll || !_scrollController.hasClients) return;

    // Pause at start for 1.5 seconds so the user can read it first
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || !_shouldScroll || !_scrollController.hasClients) return;

    final scrollLimit = _textWidth + widget.gap;
    final duration = Duration(milliseconds: ((scrollLimit / widget.velocity) * 1000).toInt());

    await _scrollController.animateTo(
      scrollLimit,
      duration: duration,
      curve: Curves.linear,
    );

    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
      _animate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldScroll) {
      return Center(
        child: Text.rich(
          widget.textSpan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Row(
            children: [
              Text.rich(widget.textSpan),
              SizedBox(width: widget.gap),
            ],
          );
        },
      ),
    );
  }
}

