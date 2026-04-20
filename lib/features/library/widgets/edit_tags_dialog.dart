import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class EditTagsDialog extends StatefulWidget {
  final SongModel song;
  final Function(Map<String, String>) onSave;

  const EditTagsDialog({super.key, required this.song, required this.onSave});

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist ?? '');
    _albumController = TextEditingController(text: widget.song.album ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Edit Metadata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField('Title', _titleController),
            _buildField('Artist', _artistController),
            _buildField('Album', _albumController),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {}, // Future: image_picker for cover
              icon: const Icon(Icons.image_rounded, color: Color(0xFF39FF14)),
              label: const Text('Change Cover', style: TextStyle(color: Color(0xFF39FF14))),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            widget.onSave({
              'title': _titleController.text,
              'artist': _artistController.text,
              'album': _albumController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Color(0xFF39FF14))),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF39FF14))),
      ),
    );
  }
}
