import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/services/file_management_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music/core/utils/metadata_helper.dart';
import 'package:music/core/providers/service_providers.dart';
import 'package:music/features/library/widgets/rename_dialog.dart';
import 'package:music/features/library/widgets/edit_tags_dialog.dart';
import 'package:music/features/library/providers/music_provider.dart';

class SongActionSheet extends ConsumerWidget {
  final SongModel song;

  const SongActionSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileService = ref.read(fileManagementServiceProvider);
    final metaService = ref.read(metadataServiceProvider);
    final isHidden = fileService.isHidden(song.id);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(color: Theme.of(context).colorScheme.outline),
            _buildActionItem(context, Icons.play_arrow_rounded, 'Play', () {
              // Implementation in Phase 2
            }),
            _buildActionItem(context, Icons.playlist_add_rounded, 'Add to playlist', () {}),
            _buildActionItem(context, Icons.flash_on_rounded, 'Add to Moment', () {}),
            
            // Phase 6 Actions
            _buildActionItem(context, Icons.edit_rounded, 'Rename File', () {
              showDialog(
                context: context,
                builder: (ctx) => RenameDialog(
                  currentName: song.title,
                  onRename: (newName) async {
                    final success = await fileService.renameSong(song.data, newName);
                    if (success) {
                      ref.invalidate(localSongsProvider);
                      _showSuccess(context, 'Song renamed!');
                    }
                  },
                ),
              );
            }),
            _buildActionItem(context, Icons.label_important_rounded, 'Edit Metadata', () {
              showDialog(
                context: context,
                builder: (ctx) => EditTagsDialog(
                  song: song,
                  onSave: (tags) async {
                    final success = await metaService.updateTags(
                      song.data,
                      title: tags['title'],
                      artist: tags['artist'],
                      album: tags['album'],
                    );
                    if (success) {
                      ref.invalidate(localSongsProvider);
                      _showSuccess(context, 'Metadata updated!');
                    }
                  },
                ),
              );
            }),
            _buildActionItem(context, isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, isHidden ? 'Unhide Song' : 'Hide Song', () async {
              await fileService.toggleHideSong(song.id);
              ref.invalidate(localSongsProvider);
              _showSuccess(context, isHidden ? 'Song visible again' : 'Song hidden');
            }),
            _buildActionItem(context, Icons.music_note_rounded, 'Set as Ringtone', () async {
              final success = await fileService.setAsRingtone(song.data, song.title);
              if (success) {
                _showSuccess(context, 'Ringtone set successfully!');
              }
            }),
            _buildActionItem(context, Icons.delete_outline_rounded, 'Delete permanently', () async {
              final confirm = await _showDeleteConfirm(context);
              if (confirm == true) {
                try {
                  final success = await fileService.deleteSong(song.id, song.data);
                  if (success) {
                    ref.invalidate(localSongsProvider);
                    if (context.mounted) _showSuccess(context, 'Song deleted');
                  } else {
                    if (context.mounted) _showErrorWithSettings(context, 'Permission denied', fileService);
                  }
                } catch (e) {
                  if (context.mounted) _showErrorWithSettings(context, 'Deletion failed', fileService);
                }
              }
            }, color: Colors.redAccent),
            
            _buildActionItem(context, Icons.share_rounded, 'Share', () {}),
            _buildActionItem(context, Icons.info_outline_rounded, 'View details', () {}),
          ],
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF39FF14).withOpacity(0.8)),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent.withOpacity(0.8)),
    );
  }

  void _showErrorWithSettings(BuildContext context, String message, FileManagementService service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        action: SnackBarAction(
          label: 'OPEN SETTINGS',
          textColor: Colors.white,
          onPressed: () => service.openManageStorageSettings(),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Delete File?'),
        content: const Text('This will permanently delete the file from your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/default_album_art.png',
                fit: BoxFit.cover,
                width: 50,
                height: 50,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MetadataHelper.cleanMetadata(song.title, song.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                ),
                Text(
                  MetadataHelper.cleanArtist(song.artist),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.onSurface.withOpacity(0.7)),
      title: Text(label, style: TextStyle(color: color ?? theme.colorScheme.onSurface)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

void showSongActionSheet(BuildContext context, SongModel song) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SongActionSheet(song: song),
  );
}
