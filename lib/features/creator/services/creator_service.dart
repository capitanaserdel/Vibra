import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class CreatorService {
  final _recorder = AudioRecorder();

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final directory = await getTemporaryDirectory();
    final path = p.join(directory.path, 'voice_recording.m4a');
    
    await _recorder.start(const RecordConfig(), path: path);
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<String?> mergeVoiceAndBeat(String voicePath, String beatPath) async {
    final directory = await getExternalStorageDirectory();
    final outputDir = Directory(p.join(directory!.path, 'Vibra', 'music'));
    
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final outputPath = p.join(outputDir.path, 'Vibra_Creation_${DateTime.now().millisecondsSinceEpoch}.mp3');

    // FFmpeg command to mix two audio files
    final command = '-i "$beatPath" -i "$voicePath" -filter_complex amix=inputs=2:duration=first:dropout_transition=2 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      print('FFmpeg failed with return code $returnCode');
      return null;
    }
  }
}
