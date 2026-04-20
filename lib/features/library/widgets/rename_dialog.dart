import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onRename;

  const RenameDialog({super.key, required this.currentName, required this.onRename});

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Rename Song'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter new name',
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF39FF14))),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            widget.onRename(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Rename', style: TextStyle(color: Color(0xFF39FF14))),
        ),
      ],
    );
  }
}
