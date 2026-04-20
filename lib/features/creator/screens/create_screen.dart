import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/creator/services/creator_service.dart';
import 'package:music/features/library/providers/music_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

final creatorServiceProvider = Provider((ref) => CreatorService());

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _isRecording = false;
  String? _recordedVoicePath;
  SongModel? _selectedBeat;
  bool _isMerging = false;

  void _toggleRecording() async {
    final service = ref.read(creatorServiceProvider);
    if (_isRecording) {
      final path = await service.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedVoicePath = path;
      });
    } else {
      await service.startRecording();
      setState(() => _isRecording = true);
    }
  }

  void _merge() async {
    if (_recordedVoicePath == null || _selectedBeat == null) return;

    setState(() => _isMerging = true);
    final service = ref.read(creatorServiceProvider);
    
    // In a real app, _selectedBeat.data would be the path
    final resultPath = await service.mergeVoiceAndBeat(_recordedVoicePath!, _selectedBeat!.data);
    
    setState(() => _isMerging = false);

    if (resultPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Vibra Library!', style: TextStyle(color: Colors.black)),
          backgroundColor: Color(0xFF39FF14),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to merge audio.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localSongs = ref.watch(localSongsProvider).value ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Creator Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Recording Section
            _buildSectionCard(
              child: Column(
                children: [
                  const Text('1. Record your voice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : const Color(0xFF39FF14),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isRecording) BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.black, size: 40),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isRecording ? 'Recording...' : (_recordedVoicePath != null ? 'Voice Recorded!' : 'Tap to start'),
                    style: TextStyle(color: _isRecording ? Colors.red : Colors.white70),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // Beat Selection Section
            _buildSectionCard(
              child: Column(
                children: [
                  const Text('2. Select a beat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (_selectedBeat != null)
                    ListTile(
                      leading: const Icon(Icons.music_note_rounded, color: Color(0xFF39FF14)),
                      title: Text(_selectedBeat!.title),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedBeat = null)),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showBeatPicker(localSongs),
                      child: const Text('Pick from Library'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Export Section
            if (_isMerging)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: (_recordedVoicePath != null && _selectedBeat != null) ? _merge : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF39FF14),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('MERGE AND EXPORT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  void _showBeatPicker(List<SongModel> songs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return ListTile(
            title: Text(song.title),
            subtitle: Text(song.artist ?? 'Unknown'),
            onTap: () {
              setState(() => _selectedBeat = song);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
