import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class TrackCarousel extends StatelessWidget {
  final List<MediaItem> tracks;
  final Function(MediaItem) onTrackTap;
  final String? currentTrackId;

  const TrackCarousel({
    super.key,
    required this.tracks,
    required this.onTrackTap,
    this.currentTrackId,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox(height: 100);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isActive = track.id == currentTrackId;

          return GestureDetector(
            onTap: () => onTrackTap(track),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? const Color(0xFF39FF14) : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/images/default_album_art.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          if (isActive)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded, color: Color(0xFF39FF14)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? Colors.white : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
