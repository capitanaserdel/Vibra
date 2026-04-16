import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/audio/providers/player_provider.dart';
import 'package:music/features/ui/screens/settings_screen.dart';

class ExploreView extends ConsumerWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularStations = ref.watch(popularStationsProvider);
    final searchedStations = ref.watch(searchedStationsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search online stations...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: query.isEmpty
          ? popularStations.when(
              data: (stations) => _buildStationList(stations, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading stations: $e')),
            )
          : searchedStations.when(
              data: (stations) => _buildStationList(stations, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error searching: $e')),
            ),
    );
  }

  Widget _buildStationList(List<dynamic> stations, WidgetRef ref) {
    if (stations.isEmpty) return const Center(child: Text('No stations found.'));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 16),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        return ListTile(
          leading: station.favicon.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: station.favicon,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.radio_rounded),
                    errorWidget: (context, url, error) => const Icon(Icons.radio_rounded),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.radio_rounded, color: Colors.white54),
                ),
          title: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(station.tags, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
          onTap: () {
            ref.read(playerNotifierProvider.notifier).playOnlineStation(station);
          },
        );
      },
    );
  }
}
