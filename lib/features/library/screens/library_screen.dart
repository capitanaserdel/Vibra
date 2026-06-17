import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/library/providers/playlist_provider.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/settings/screens/settings_screen.dart';
import 'package:music/features/player/screens/player_screen.dart';
import 'package:music/core/utils/metadata_helper.dart';
import 'package:music/shared/widgets/song_action_sheet.dart';
import 'package:on_audio_query/on_audio_query.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Widget _buildAppBarButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: theme.colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: color ?? theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSongs = ref.watch(localSongsProvider);
    final artists = ref.watch(artistsProvider);
    final albums = ref.watch(albumsProvider);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            _buildAppBarButton(
              context,
              icon: Icons.sort_rounded,
              color: Theme.of(context).colorScheme.primary,
              onPressed: () => _showSortSheet(context, ref),
            ),
            _buildAppBarButton(
              context,
              icon: Icons.sync_rounded,
              onPressed: () {
                ref.invalidate(localSongsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Scanning library...'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            _buildAppBarButton(
              context,
              icon: Icons.settings_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(115),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    onChanged: (val) => ref.read(librarySearchProvider.notifier).state = val,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search offline music...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.primary),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  ),
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(localSongs.maybeWhen(
                          data: (list) => 'Songs (${list.length})',
                          orElse: () => 'Songs',
                        )),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(artists.maybeWhen(
                          data: (list) => 'Artists (${list.length})',
                          orElse: () => 'Artists',
                        )),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(albums.maybeWhen(
                          data: (list) => 'Albums (${list.length})',
                          orElse: () => 'Albums',
                        )),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Folders'),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Favorites'),
                      ),
                    ),
                    Tab(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Playlists'),
                      ),
                    ),
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
            PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

class SongsTab extends ConsumerStatefulWidget {
  const SongsTab({super.key});

  @override
  ConsumerState<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<SongsTab> {
  late ScrollController _scrollController;
  String? _selectedLetter;
  bool _isDragging = false;

  final List<String> _alphabet = const [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLetter(List<SongModel> songs, String letter) {
    int targetIndex = -1;
    if (letter == '#') {
      targetIndex = songs.indexWhere((song) {
        final title = song.title.trim();
        if (title.isEmpty) return false;
        final firstChar = title[0].toUpperCase();
        return !RegExp(r'[A-Z]').hasMatch(firstChar);
      });
    } else {
      targetIndex = songs.indexWhere((song) {
        final title = song.title.trim();
        if (title.isEmpty) return false;
        return title[0].toUpperCase() == letter;
      });
    }

    if (targetIndex != -1) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = (targetIndex * 72.0).clamp(0.0, maxScroll);
        _scrollController.jumpTo(targetOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

        return Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
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
                        onTap: () {
                          final clickState = ref.read(songClickProvider);
                          final songUri = song.uri ?? song.data;
                          
                          if (clickState.songId == songUri) {
                            final newCount = clickState.clickCount + 1;
                            ref.read(songClickProvider.notifier).state = SongClickState(songId: songUri, clickCount: newCount);
                            
                            if (newCount >= 2) {
                              ref.read(songClickProvider.notifier).state = SongClickState();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PlayerScreen()),
                              );
                            }
                          } else {
                            ref.read(songClickProvider.notifier).state = SongClickState(songId: songUri, clickCount: 1);
                            ref.read(playerNotifierProvider.notifier).playLibrarySong(song, filteredSongs);
                          }
                        },
                        onLongPress: () => showSongActionSheet(context, song),
                      );
                    },
                  ),
                ),
                // Alphabet Scrollbar
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => setState(() => _isDragging = true),
                  onVerticalDragEnd: (_) => setState(() {
                    _isDragging = false;
                    _selectedLetter = null;
                  }),
                  onVerticalDragCancel: () => setState(() {
                    _isDragging = false;
                    _selectedLetter = null;
                  }),
                  onVerticalDragUpdate: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final letterHeight = renderBox.size.height / _alphabet.length;
                    int index = (localPosition.dy / letterHeight).floor();
                    if (index >= 0 && index < _alphabet.length) {
                      final letter = _alphabet[index];
                      if (_selectedLetter != letter) {
                        setState(() {
                          _selectedLetter = letter;
                        });
                        _scrollToLetter(filteredSongs, letter);
                      }
                    }
                  },
                  onTapDown: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final letterHeight = renderBox.size.height / _alphabet.length;
                    int index = (localPosition.dy / letterHeight).floor();
                    if (index >= 0 && index < _alphabet.length) {
                      final letter = _alphabet[index];
                      setState(() {
                        _isDragging = true;
                        _selectedLetter = letter;
                      });
                      _scrollToLetter(filteredSongs, letter);
                    }
                  },
                  onTapUp: (_) => setState(() {
                    _isDragging = false;
                    _selectedLetter = null;
                  }),
                  child: Container(
                    width: 30,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _alphabet.map((letter) {
                        final isSelected = _selectedLetter == letter;
                        return Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: isSelected ? BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ) : null,
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                ? Theme.of(context).colorScheme.onPrimary 
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            // Floating Letter Indicator Bubble
            if (_isDragging && _selectedLetter != null)
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    _selectedLetter!,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
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

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSongsAsync = ref.watch(localSongsProvider);
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: Hive.box('metadata_box').listenable(),
      builder: (context, box, _) {
        final favoriteIds = <String>{};
        for (final key in box.keys) {
          final val = box.get(key);
          if (val is Map && val['isFavorite'] == true) {
            favoriteIds.add(key.toString());
          }
        }

        if (favoriteIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('No favorites yet', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 16)),
                const SizedBox(height: 8),
                Text('Tap \u2665 on any song in the player to add it here',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.35), fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return localSongsAsync.when(
          data: (allSongs) {
            final favSongs = allSongs
                .where((s) => favoriteIds.contains(s.uri ?? s.data))
                .toList();

            if (favSongs.isEmpty) {
              return Center(
                child: Text('Favorited songs not found on device',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: favSongs.length,
              itemBuilder: (context, index) {
                final song = favSongs[index];
                final songId = song.uri ?? song.data;
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
                    style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    MetadataHelper.cleanArtist(song.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: 20),
                    tooltip: 'Remove from Favorites',
                    onPressed: () {
                      final current = box.get(songId);
                      final updated = (current is Map)
                          ? Map<String, dynamic>.from(current)
                          : <String, dynamic>{};
                      updated['isFavorite'] = false;
                      box.put(songId, updated);
                    },
                  ),
                  onTap: () {
                    final clickState = ref.read(songClickProvider);
                    if (clickState.songId == songId) {
                      final newCount = clickState.clickCount + 1;
                      ref.read(songClickProvider.notifier).state =
                          SongClickState(songId: songId, clickCount: newCount);
                      if (newCount >= 2) {
                        ref.read(songClickProvider.notifier).state = SongClickState();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlayerScreen()),
                        );
                      }
                    } else {
                      ref.read(songClickProvider.notifier).state =
                          SongClickState(songId: songId, clickCount: 1);
                      ref.read(playerNotifierProvider.notifier).playLibrarySong(song, favSongs);
                    }
                  },
                  onLongPress: () => showSongActionSheet(context, song),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: \$e')),
        );
      },
    );
  }
}


class PlaylistsTab extends ConsumerStatefulWidget {
  const PlaylistsTab({super.key});
  @override
  ConsumerState<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<PlaylistsTab> {
  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (_) {
            final name = ctrl.text.trim();
            if (name.isNotEmpty) {
              ref.read(playlistProvider.notifier).createPlaylist(name);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistProvider.notifier).createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'create_playlist_fab',
        onPressed: () => _showCreateDialog(context),
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
        tooltip: 'New Playlist',
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No playlists yet', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to create your first playlist',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.35), fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final name = playlists[index];
                final count = ref.read(playlistProvider.notifier).getPlaylistSongs(name).length;
                return Dismissible(
                  key: ValueKey(name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Colors.red.withOpacity(0.8),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: theme.colorScheme.surface,
                        title: const Text('Delete Playlist?'),
                        content: Text('Delete "$name"? This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref.read(playlistProvider.notifier).deletePlaylist(name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" deleted'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      child: Icon(Icons.queue_music_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    subtitle: Text('$count song${count == 1 ? '' : 's'}',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlistName: name)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistName;
  const PlaylistDetailScreen({super.key, required this.playlistName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songIds = ref.watch(playlistProvider.notifier).getPlaylistSongs(playlistName);
    final localSongsAsync = ref.watch(localSongsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Delete playlist',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: theme.colorScheme.surface,
                  title: const Text('Delete Playlist?'),
                  content: Text('Delete "$playlistName"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                ref.read(playlistProvider.notifier).deletePlaylist(playlistName);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: localSongsAsync.when(
        data: (allSongs) {
          final songs = allSongs.where((s) => songIds.contains(s.uri ?? s.data)).toList();
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No songs in this playlist',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Play All button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(playerNotifierProvider.notifier).playLibrarySong(songs.first, songs);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlayerScreen()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Play All (${songs.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
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
                        style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        MetadataHelper.cleanArtist(song.artist),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20),
                        tooltip: 'Remove from playlist',
                        onPressed: () {
                          ref.read(playlistProvider.notifier)
                              .removeSongFromPlaylist(playlistName, song.uri ?? song.data);
                        },
                      ),
                      onTap: () {
                        ref.read(playerNotifierProvider.notifier).playLibrarySong(song, songs);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlayerScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


void _showSortSheet(BuildContext context, WidgetRef ref) {
  final currentSort = ref.read(librarySortTypeProvider);
  final isAsc = ref.read(librarySortAscendingProvider);

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SORT BY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              Divider(color: Theme.of(context).colorScheme.outline, height: 24),
              _sortTile(context, ref, 'Song Name', LibrarySortType.songName, currentSort),
              _sortTile(context, ref, 'Artist Name', LibrarySortType.artistName, currentSort),
              _sortTile(context, ref, 'Album Name', LibrarySortType.albumName, currentSort),
              _sortTile(context, ref, 'Folder Name', LibrarySortType.folderName, currentSort),
              _sortTile(context, ref, 'Added Time', LibrarySortType.addedTime, currentSort),
              _sortTile(context, ref, 'Duration', LibrarySortType.duration, currentSort),
              _sortTile(context, ref, 'Year', LibrarySortType.year, currentSort),
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
