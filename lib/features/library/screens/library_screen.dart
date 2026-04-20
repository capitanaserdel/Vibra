import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/settings/screens/settings_screen.dart';
import 'package:music/core/utils/metadata_helper.dart';
import 'package:music/shared/widgets/song_action_sheet.dart';
import 'package:on_audio_query/on_audio_query.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                Icons.sort_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => _showSortSheet(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: () {
                ref.invalidate(localSongsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('Scanning library...'), backgroundColor: Theme.of(context).colorScheme.primary),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    onChanged: (val) => ref.read(librarySearchProvider.notifier).state = val,
                    decoration: InputDecoration(
                      hintText: 'Search offline music...',
                      prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Artists'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Folders'),
                    Tab(text: 'Favorites'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            SongsTab(),
            ArtistsTab(),
            AlbumsTab(),
            FoldersTab(),
            FavoritesTab(),
          ],
        ),
      ),
    );
  }
}

class SongsTab extends ConsumerWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSongs = ref.watch(localSongsProvider);
    final query = ref.watch(librarySearchProvider).toLowerCase();

    return localSongs.when(
      data: (songs) {
        final filteredSongs = songs.where((s) => 
          s.title.toLowerCase().contains(query) || 
          (s.artist?.toLowerCase().contains(query) ?? false)
        ).toList();

        if (filteredSongs.isEmpty) {
          return const Center(child: Text('No songs found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: filteredSongs.length,
          itemBuilder: (context, index) {
            final song = filteredSongs[index];
            return ListTile(
              leading: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: _defaultArtwork(),
              ),
              title: Text(
                MetadataHelper.cleanMetadata(song.title, song.displayName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              ),
              subtitle: Text(
                MetadataHelper.cleanArtist(song.artist),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              trailing: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              onTap: () => ref.read(playerNotifierProvider.notifier).playLibrarySong(song, filteredSongs),
              onLongPress: () => showSongActionSheet(context, song),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);

    return artists.when(
      data: (list) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final artist = list[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              child: Icon(Icons.person_outline_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            title: Text(MetadataHelper.cleanArtist(artist.artist), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text('${artist.numberOfTracks} Tracks', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);

    return albums.when(
      data: (list) => GridView.builder(
        padding: const EdgeInsets.all(16).copyWith(bottom: 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final album = list[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: QueryArtworkWidget(
                  id: album.id,
                  type: ArtworkType.ALBUM,
                  nullArtworkWidget: _defaultArtwork(size: 150),
                ),
              ),
              const SizedBox(height: 8),
              Text(album.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              Text(MetadataHelper.cleanArtist(album.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
            ],
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class FoldersTab extends StatelessWidget {
  const FoldersTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Folders View coming soon'));
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Favorites View coming soon'));
}


void _showSortSheet(BuildContext context, WidgetRef ref) {
  final currentSort = ref.read(librarySortTypeProvider);
  final isAsc = ref.read(librarySortAscendingProvider);

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SORT BY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          Divider(color: Theme.of(context).colorScheme.outline, height: 24),
          _sortTile(context, ref, 'Title (A-Z)', LibrarySortType.aToZ, currentSort),
          _sortTile(context, ref, 'Artist', LibrarySortType.artist, currentSort),
          _sortTile(context, ref, 'Date Added', LibrarySortType.dateAdded, currentSort),
          _sortTile(context, ref, 'Duration', LibrarySortType.duration, currentSort),
          Divider(color: Theme.of(context).colorScheme.outline),
          ListTile(
            leading: Icon(isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: Theme.of(context).colorScheme.primary),
            title: Text(isAsc ? 'Ascending' : 'Descending', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            trailing: Switch(
              value: isAsc,
              onChanged: (val) {
                ref.toggleSortDirection();
                Navigator.pop(context);
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _sortTile(BuildContext context, WidgetRef ref, String title, LibrarySortType type, LibrarySortType current) {
  final isSelected = type == current;
  final theme = Theme.of(context);
  return ListTile(
    title: Text(title, style: TextStyle(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
    onTap: () {
      ref.updateSortType(type);
      Navigator.pop(context);
    },
  );
}

Widget _defaultArtwork({double size = 40}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/images/default_album_art.png',
      fit: BoxFit.cover,
      width: size,
      height: size,
    ),
  );
}
