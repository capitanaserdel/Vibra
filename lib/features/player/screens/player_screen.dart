import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/player/widgets/circular_progress_ring.dart';
import 'package:music/features/player/widgets/lyrics_view.dart';
import 'package:music/features/player/widgets/track_carousel.dart';
import 'package:music/features/player/widgets/linear_player.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;

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
          _buildBackground(context, mediaItem.artUri?.toString()),

          SafeArea(
            child: Column(
              children: [
                // 2. Navigation Header
                _buildTopTabs(context),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        
                        // 3. Main Player (Circular / Linear)
                        _showLyrics
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: LyricsView(),
                              )
                            : GestureDetector(
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
                       // _buildSecondaryControls(context),

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

  Widget _buildBackground(BuildContext context, String? imageUrl) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

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

    return Stack(
      children: [
        Container(
          color: theme.colorScheme.background,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? QueryArtworkWidget(
                  id: int.tryParse(imageUrl) ?? 0,
                  type: ArtworkType.AUDIO,
                  nullArtworkWidget: const SizedBox.shrink(),
                )
              : const Image(image: AssetImage('assets/images/default_album_art.png'), fit: BoxFit.cover),
        ),
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
            onPressed: () {},
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
            imageUrl != null && imageUrl.isNotEmpty ? 
              QueryArtworkWidget(
                id: int.tryParse(imageUrl) ?? 0,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Image.asset('assets/images/default_album_art.png', fit: BoxFit.cover),
              ) : 
              Image.asset('assets/images/default_album_art.png', fit: BoxFit.cover),
            
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
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onBackground),
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onBackground.withOpacity(0.6)),
          ),
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildIconControl(context, Icons.favorite_border_rounded),
        _buildIconControl(context, Icons.alarm_rounded),
        _buildIconControl(context, Icons.playlist_add_rounded),
        _buildIconControl(context, Icons.queue_music_rounded),
        _buildIconControl(context, Icons.tune_rounded),
      ],
    );
  }

  Widget _buildIconControl(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon, color: theme.colorScheme.onBackground.withOpacity(0.7), size: 24),
      onPressed: () {},
    ) ;
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
    final localSongs = ref.watch(localSongsProvider).value ?? [];
    
    final library = localSongs.map((song) => MediaItem(
      id: song.uri ?? song.data,
      album: song.album ?? 'Unknown Album',
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: Uri.parse('content://media/external/audio/albumart/${song.albumId}'),
    )).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text("Up Next", style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        TrackCarousel(
          tracks: library,
          currentTrackId: currentTrackId,
          onTrackTap: (track) {
            ref.read(playerNotifierProvider.notifier).playMediaItem(track);
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
