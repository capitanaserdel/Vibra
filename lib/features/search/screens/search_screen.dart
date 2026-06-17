import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:music/features/player/providers/player_provider.dart';
import 'package:music/features/player/screens/player_screen.dart';
import 'package:music/features/streaming/services/online_music_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music/core/providers/service_providers.dart';
import 'package:music/features/search/widgets/shazam_bottom_sheet.dart';

// --- Search History Provider ---
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final box = Hive.box('settings_box');
    final List<dynamic>? list = box.get('search_history');
    if (list != null) {
      state = list.cast<String>().toList();
    }
  }

  void addQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    
    final updated = List<String>.from(state);
    updated.remove(trimmed);
    updated.insert(0, trimmed);
    if (updated.length > 10) {
      updated.removeLast();
    }
    state = updated;
    Hive.box('settings_box').put('search_history', updated);
  }

  void removeQuery(String query) {
    final updated = List<String>.from(state)..remove(query);
    state = updated;
    Hive.box('settings_box').put('search_history', updated);
  }

  void clearHistory() {
    state = [];
    Hive.box('settings_box').put('search_history', <String>[]);
  }
}

// --- Downloading Tracks Provider ---
final downloadingTracksProvider = StateNotifierProvider<DownloadingTracksNotifier, Map<String, double>>((ref) {
  return DownloadingTracksNotifier();
});

class DownloadingTracksNotifier extends StateNotifier<Map<String, double>> {
  DownloadingTracksNotifier() : super({});

  void setProgress(String trackId, double progress) {
    state = {...state, trackId: progress};
  }

  void completeDownload(String trackId) {
    final copy = Map<String, double>.from(state);
    copy.remove(trackId);
    state = copy;
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Synchronize the search controller with provider state on startup if search already active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentQuery = ref.read(searchQueryProvider);
      if (currentQuery.isNotEmpty) {
        _searchController.text = currentQuery;
      }
    });
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
        return true;
      }
      
      if (await Permission.storage.request().isGranted) {
        return true;
      }

      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      if (context.mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('Storage Permission Required'),
            content: const Text('To download and save music directly to your public Music folder so it shows up in your library, Vibra needs the "All Files Access" permission.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          try {
            await ref.read(fileManagementServiceProvider).openManageStorageSettings();
          } catch (_) {}
        }
      }
      return false;
    }
    return true;
  }

  String _getTrackExtension(OnlineTrack track) {
    try {
      final uri = Uri.parse(track.previewUrl);
      String ext = p.extension(uri.path);
      if (ext == '.mp4') return '.m4a';
      return ext.isNotEmpty ? ext : '.mp3';
    } catch (_) {
      return '.mp3';
    }
  }

  Future<bool> _isTrackDownloaded(OnlineTrack track) async {
    try {
      final fileService = ref.read(fileManagementServiceProvider);
      final outputDir = await fileService.getDownloadDirectory();
      if (outputDir == null) return false;
      final sanitizedTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final sanitizedArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      final legacyFile = File(p.join(outputDir.path, '${sanitizedTitle}_$sanitizedArtist.mp3'));
      if (await legacyFile.exists()) return true;

      final ext = _getTrackExtension(track);
      if (ext != '.mp3') {
        final correctFile = File(p.join(outputDir.path, '${sanitizedTitle}_$sanitizedArtist$ext'));
        if (await correctFile.exists()) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _downloadTrack(WidgetRef ref, BuildContext context, OnlineTrack track) async {
    final hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) return;

    final notifier = ref.read(downloadingTracksProvider.notifier);
    notifier.setProgress(track.id, 0.0);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(track.previewUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Server returned status code ${response.statusCode}");
      }

      final contentLength = response.contentLength ?? 0;
      
      final fileService = ref.read(fileManagementServiceProvider);
      final outputDir = await fileService.getDownloadDirectory();
      if (outputDir == null) throw Exception("Could not access external storage");
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final sanitizedTitle = track.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final sanitizedArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final ext = _getTrackExtension(track);
      final filename = '${sanitizedTitle}_$sanitizedArtist$ext';
      final file = File(p.join(outputDir.path, filename));
      final sink = file.openWrite();

      int downloaded = 0;
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          final progress = downloaded / contentLength;
          notifier.setProgress(track.id, progress);
        }
      });

      await sink.close();
      client.close();

      // Trigger MediaScanner scan so it shows up in Local Library
      final onAudioQuery = OnAudioQuery();
      await onAudioQuery.scanMedia(file.path);

      // Invalidate the local songs provider so the library screen lists update!
      ref.invalidate(localSongsProvider);

      notifier.completeDownload(track.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded "${track.title}" successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Force rebuild of download button state
      setState(() {});
    } catch (e) {
      notifier.completeDownload(track.id);
      print("Download error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download "${track.title}": $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper list of genres with custom gradients and icons
  final List<Map<String, dynamic>> _genres = [
    {
      'name': 'Pop',
      'icon': Icons.music_note_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Rock',
      'icon': Icons.album_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Jazz',
      'icon': Icons.library_music_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Classical',
      'icon': Icons.piano_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Dance',
      'icon': Icons.graphic_eq_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Hip-Hop',
      'icon': Icons.mic_external_on_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Lofi',
      'icon': Icons.bedtime_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'name': 'Chill',
      'icon': Icons.spa_rounded,
      'gradient': const LinearGradient(
        colors: [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: query.isEmpty
                  ? _buildExploreView()
                  : _buildSearchResultsView(query),
            ),
          ],
        ),
      ),
    );
  }

  void _startIdentifySong(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ShazamBottomSheet(),
    );
  }

  Widget _buildIdentifySongCard() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.12),
            theme.colorScheme.tertiary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _startIdentifySong(context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.center_focus_strong_rounded,
                    size: 26,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identify Playing Song',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Listen to music playing nearby to find and stream it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasQuery = _searchController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: (val) {
            // Keep provider updated for live filtering
            ref.read(searchQueryProvider.notifier).state = val;
          },
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              ref.read(searchQueryProvider.notifier).state = trimmed;
              ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
            }
          },
          decoration: InputDecoration(
            hintText: 'Search online music & radio...',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = "";
                      _focusNode.unfocus();
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.mic_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _startIdentifySong(context),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreView() {
    final history = ref.watch(searchHistoryProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (history.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(searchHistoryProvider.notifier).clearHistory();
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.text = item;
                        ref.read(searchQueryProvider.notifier).state = item;
                        ref.read(searchHistoryProvider.notifier).addQuery(item);
                        _focusNode.unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                ref.read(searchHistoryProvider.notifier).removeQuery(item);
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: _buildIdentifySongCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              'Explore Genres',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Add padding at bottom to clear mini player
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final genre = _genres[index];
                return GestureDetector(
                  onTap: () {
                    final name = genre['name'] as String;
                    _searchController.text = name;
                    ref.read(searchQueryProvider.notifier).state = name;
                    ref.read(searchHistoryProvider.notifier).addQuery(name);
                    _focusNode.unfocus();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: genre['gradient'] as LinearGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (genre['gradient'] as LinearGradient).colors[0].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -15,
                          bottom: -15,
                          child: Transform.rotate(
                            angle: 0.2,
                            child: Icon(
                              genre['icon'] as IconData,
                              size: 72,
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            genre['name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _genres.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView(String query) {
    final searchedSongs = ref.watch(searchedSongsProvider);
    final mediaItem = ref.watch(currentMediaItemProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;

    return searchedSongs.when(
      data: (songs) {
        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No songs found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Padding to clear player bar
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final track = songs[index];
            final isCurrentTrack = mediaItem != null && mediaItem.id == track.previewUrl;
            final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);
            final isLoading = isCurrentTrack && (playbackState?.processingState == AudioProcessingState.buffering || playbackState?.processingState == AudioProcessingState.loading);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isCurrentTrack
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentTrack
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: _buildArtwork(track.coverUrl),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${track.artist} • ${track.album}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDownloadButton(ref, track),
                      const SizedBox(width: 8),
                      _buildPlayIndicator(track, isCurrentTrack, isPlaying, isLoading),
                    ],
                  ),
                  onTap: () {
                    if (isCurrentTrack) {
                      ref.read(playerNotifierProvider.notifier).togglePlay();
                    } else {
                      ref.read(playerNotifierProvider.notifier).playOnlineTrack(track);
                    }
                    // Add current query to history as a successful search interaction
                    ref.read(searchHistoryProvider.notifier).addQuery(query);
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load songs: $e',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(WidgetRef ref, OnlineTrack track) {
    final downloadProgress = ref.watch(downloadingTracksProvider)[track.id];
    final isDownloading = downloadProgress != null;

    if (isDownloading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          value: downloadProgress > 0 ? downloadProgress : null,
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _isTrackDownloaded(track),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        if (isDownloaded) {
          return Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade400,
            size: 24,
          );
        }
        return IconButton(
          icon: Icon(
            Icons.download_for_offline_rounded,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            size: 24,
          ),
          onPressed: () => _downloadTrack(ref, context, track),
        );
      },
    );
  }

  Widget _buildPlayIndicator(OnlineTrack track, bool isCurrentTrack, bool isPlaying, bool isLoading) {
    if (isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCurrentTrack
            ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
            : Theme.of(context).colorScheme.primary.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCurrentTrack && isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildArtwork(String url) {
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
    );

    if (url.isEmpty || !url.startsWith('http')) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 52,
          height: 52,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
