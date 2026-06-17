import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/player/screens/player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;

    if (mediaItem == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlayerScreen()),
        );
      },
      child: Container(
        height: 65,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                Hero(
                  tag: 'artwork',
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box('metadata_box').listenable(),
                      builder: (context, box, _) {
                        final meta = box.get(mediaItem.id);
                        final customArtPath = (meta is Map) ? meta['customArtworkPath'] as String? : null;
                        final hasCustomArt = customArtPath != null && customArtPath.isNotEmpty && File(customArtPath).existsSync();

                        if (hasCustomArt) {
                          return Image.file(
                            File(customArtPath),
                            fit: BoxFit.cover,
                            width: 45,
                            height: 45,
                          );
                        }

                        final imageUrl = mediaItem.artUri?.toString();
                        final isNetwork = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

                        if (isNetwork) {
                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: 45,
                            height: 45,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/default_album_art.png',
                              fit: BoxFit.cover,
                            ),
                          );
                        }

                        int? albumId;
                        if (imageUrl != null) {
                          if (imageUrl.contains('albumart/')) {
                            albumId = int.tryParse(imageUrl.split('albumart/').last);
                          } else {
                            albumId = int.tryParse(imageUrl);
                          }
                        }

                        if (albumId != null && albumId != 0) {
                          return QueryArtworkWidget(
                            id: albumId,
                            type: ArtworkType.ALBUM,
                            artworkWidth: 45,
                            artworkHeight: 45,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Image.asset(
                              'assets/images/default_album_art.png',
                              fit: BoxFit.cover,
                            ),
                          );
                        }

                        return Image.asset(
                          'assets/images/default_album_art.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mediaItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mediaItem.artist ?? 'Unknown Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    playbackState?.playing ?? false
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 30,
                  ),
                  onPressed: () => ref.read(playerNotifierProvider.notifier).togglePlay(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
