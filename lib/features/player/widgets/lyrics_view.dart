import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/player/lyrics/providers/lyrics_provider.dart';

class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || (lyrics.plainLyrics == null && lyrics.syncedLyrics == null)) {
          return const Center(
            child: Text(
              'No lyrics found for this track.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        // For now, we'll display the plain lyrics
        // A more advanced version would parse syncedLyrics and auto-scroll
        final displayLyrics = lyrics.plainLyrics ?? _stripTimestamps(lyrics.syncedLyrics!);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              displayLyrics,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 2.0,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(
        child: Text('Error loading lyrics.', style: TextStyle(color: Colors.white54)),
      ),
    );
  }

  String _stripTimestamps(String synced) {
    // Simple regex to remove [mm:ss.xx] timestamps
    return synced.replaceAll(RegExp(r'\[\d{2}:\d{2}.\d{2,3}\]'), '').trim();
  }
}
