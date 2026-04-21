import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/player/lyrics/providers/lyrics_provider.dart';

import '../../../core/utils/metadata_helper.dart';
import '../providers/player_provider.dart';

class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentLyricsProvider);

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || (lyrics.plainLyrics == null && lyrics.syncedLyrics == null)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notes_rounded, size: 48, color: onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No lyrics found for this track.',
                  style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: () => ref.invalidate(currentLyricsProvider),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => _showManualSearchDialog(context, ref),
                      label: const Text('Edit Search Info'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final displayLyrics = lyrics.plainLyrics ?? _stripTimestamps(lyrics.syncedLyrics!);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              children: [
                Text(
                  displayLyrics,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 2.2,
                    color: onSurface,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 40),
                TextButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  onPressed: () => _showManualSearchDialog(context, ref),
                  label: Text('Not the right lyrics? Edit Search', 
                    style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.4))),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              strokeWidth: 2,
            ),
            const SizedBox(height: 20),
            Text('Searching lyrics...', style: TextStyle(color: onSurface.withOpacity(0.6))),
          ],
        ),
      ),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Network error loading lyrics.', style: TextStyle(color: onSurface.withOpacity(0.6))),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _showManualSearchDialog(context, ref),
              child: const Text('Search Manually'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualSearchDialog(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.read(currentMediaItemProvider).value;
    if (mediaItem == null) return;

    final titleController = TextEditingController(text: MetadataHelper.stripNoise(mediaItem.title));
    final artistController = TextEditingController(text: MetadataHelper.getMainArtist(mediaItem.artist));
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Search Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manually enter the song info to improve search results.', 
              style: TextStyle(fontSize: 13,)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Song Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: 'Artist Name', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(manualLyricsQueryProvider.notifier).state = {
                'title': titleController.text.trim(),
                'artist': artistController.text.trim(),
              };
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  String _stripTimestamps(String synced) {
    // Simple regex to remove [mm:ss.xx] timestamps
    return synced.replaceAll(RegExp(r'\[\d{2}:\d{2}.\d{2,3}\]'), '').trim();
  }
}
