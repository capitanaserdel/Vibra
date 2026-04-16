import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/audio/providers/player_provider.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/ui/widgets/circular_progress_ring.dart';
import 'package:music/features/ui/widgets/lyrics_view.dart';
import 'package:music/features/ui/widgets/track_carousel.dart';
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

    if (mediaItem == null) return const Scaffold();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Blurred Artwork Background
          _buildBackground(mediaItem.artUri?.toString()),

          SafeArea(
            child: Column(
              children: [
                // 2. Custom Top Header (Tab Switcher)
                _buildTopTabs(context),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        
                        // 3. Artwork or Lyrics
                        _showLyrics
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: LyricsView(),
                              )
                            : _buildCircularPlayer(mediaItem.artUri?.toString(), progress, position),

                        const SizedBox(height: 30),

                        // 4. Song Info
                        _buildSongInfo(mediaItem.title, mediaItem.artist ?? 'Unknown Artist'),

                        const SizedBox(height: 30),

                        // 5. Secondary Control Row
                        _buildSecondaryControls(),

                        const SizedBox(height: 30),

                        // 6. Main Control Row
                        _buildMainControls(playbackState?.playing ?? false),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // 7. Bottom Track Carousel
                _buildBottomCarousel(mediaItem.id),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String? imageUrl) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/default_album_art.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black45,
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabItem("Song", !_showLyrics, () => setState(() => _showLyrics = false)),
                Container(width: 1, height: 12, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)),
                _buildTabItem("Lyrics", _showLyrics, () => setState(() => _showLyrics = true)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white38,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCircularPlayer(String? imageUrl, double progress, Duration position) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final duration = mediaItem?.duration ?? Duration.zero;

    return Center(
      child: CircularProgressRing(
        progress: progress,
        size: MediaQuery.of(context).size.width * 0.75,
        progressColor: const Color(0xFF39FF14),
        backgroundColor: Colors.white10,
        onSeek: (newProgress) {
          if (duration.inMilliseconds > 0) {
            final targetMs = (duration.inMilliseconds * newProgress).toInt();
            ref.read(playerNotifierProvider.notifier).seek(Duration(milliseconds: targetMs));
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Branded Artwork
            Image.asset(
              'assets/images/default_album_art.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            
            // Time Overlay
            Container(
              color: Colors.black38,
              child: Center(
                child: Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(String title, String artist) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            style: const TextStyle(fontSize: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildIconControl(Icons.favorite_border_rounded),
        _buildIconControl(Icons.alarm_rounded),
        _buildIconControl(Icons.playlist_add_rounded),
        _buildIconControl(Icons.queue_music_rounded),
        _buildIconControl(Icons.tune_rounded), // Equalizer icon
      ],
    );
  }

  Widget _buildIconControl(IconData icon) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 26),
      onPressed: () {},
    );
  }

  Widget _buildMainControls(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: const Icon(Icons.shuffle, size: 24), onPressed: () {}),
        IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 48), onPressed: () {}),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 40,
              color: Colors.white,
            ),
            onPressed: () => ref.read(playerNotifierProvider.notifier).togglePlay(),
          ),
        ),
        IconButton(icon: const Icon(Icons.skip_next_rounded, size: 48), onPressed: () {}),
        IconButton(icon: const Icon(Icons.repeat_one_rounded, size: 24), onPressed: () {}),
      ],
    );
  }

  Widget _buildBottomCarousel(String currentTrackId) {
    // Watch localSongsProvider and convert SongModel list to MediaItem list
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text("Up Next", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
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
