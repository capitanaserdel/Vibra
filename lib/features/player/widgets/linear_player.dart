import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music/features/player/providers/player_provider.dart';

class LinearPlayer extends ConsumerWidget {
  const LinearPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final duration = mediaItem?.duration ?? Duration.zero;

    if (mediaItem == null) return const SizedBox.shrink();

    final metadataBox = Hive.box('metadata_box');
    final meta = metadataBox.get(mediaItem.id);
    final customArtPath = (meta is Map) ? meta['customArtworkPath'] as String? : null;
    final hasCustomArt = customArtPath != null && customArtPath.isNotEmpty && File(customArtPath).existsSync();

    final imageUrl = mediaItem.artUri?.toString();
    final isNetwork = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
    int? albumId;
    if (imageUrl != null && !isNetwork) {
      if (imageUrl.contains('albumart/')) {
        albumId = int.tryParse(imageUrl.split('albumart/').last);
      } else {
        albumId = int.tryParse(imageUrl);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Column(
        children: [
          // Album Art
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: hasCustomArt
                    ? Image.file(
                        File(customArtPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : isNetwork
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/default_album_art.png',
                              fit: BoxFit.cover,
                            ),
                          )
                        : (albumId != null
                            ? QueryArtworkWidget(
                                id: albumId,
                                type: ArtworkType.ALBUM,
                                nullArtworkWidget: Image.asset(
                                  'assets/images/default_album_art.png',
                                  fit: BoxFit.cover,
                                ),
                                artworkWidth: double.infinity,
                                artworkHeight: double.infinity,
                                artworkFit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/images/default_album_art.png',
                                fit: BoxFit.cover,
                              )),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Linear Seek Bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.outline,
              thumbColor: Theme.of(context).colorScheme.primary,
            ),
            child: Slider(
              value: duration.inMilliseconds > 0 
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0,
              onChanged: (value) {
                if (duration.inMilliseconds > 0) {
                  final targetMs = (duration.inMilliseconds * value).toInt();
                  ref.read(playerNotifierProvider.notifier).seek(Duration(milliseconds: targetMs));
                }
              },
            ),
          ),
          
          // Time Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position), style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6), fontSize: 12)),
                Text(_formatDuration(duration), style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
