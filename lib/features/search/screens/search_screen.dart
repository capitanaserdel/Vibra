import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/core/utils/metadata_helper.dart';
import 'package:on_audio_query/on_audio_query.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search songs, artists...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            suffixIcon: _searchController.text.isNotEmpty 
              ? IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = "";
                  },
                )
              : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Local'),
            Tab(text: 'Online'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLocalResults(),
          _buildOnlineResults(),
        ],
      ),
    );
  }

  Widget _buildLocalResults() {
    final query = ref.watch(searchQueryProvider).toLowerCase();
    final localSongs = ref.watch(localSongsProvider);

    if (query.isEmpty) return const Center(child: Text('Search local music'));

    return localSongs.when(
      data: (songs) {
        final filtered = songs.where((s) => 
          s.title.toLowerCase().contains(query) || 
          (s.artist?.toLowerCase().contains(query) ?? false)
        ).toList();

        if (filtered.isEmpty) return const Center(child: Text('No local matches'));

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final song = filtered[index];
            return ListTile(
              leading: QueryArtworkWidget(id: song.id, type: ArtworkType.AUDIO),
              title: Text(MetadataHelper.cleanMetadata(song.title, song.displayName), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              subtitle: Text(MetadataHelper.cleanArtist(song.artist), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              onTap: () => ref.read(playerNotifierProvider.notifier).playSong(song),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildOnlineResults() {
    final searchedStations = ref.watch(searchedStationsProvider);
    final query = ref.watch(searchQueryProvider);

    if (query.isEmpty) return const Center(child: Text('Search online radio'));

    return searchedStations.when(
      data: (stations) {
        if (stations.isEmpty) return const Center(child: Text('No online matches'));

        return ListView.builder(
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            return ListTile(
              leading: Icon(Icons.radio_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(station.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              subtitle: Text(station.tags, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              onTap: () => ref.read(playerNotifierProvider.notifier).playOnlineStation(station),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
