import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

class FileManagementService {
  static const _channel = MethodChannel('com.example.vibra/file_management');

  /// Renames a song file on disk.
  Future<bool> renameSong(String oldPath, String newNameWithoutExtension) async {
    try {
      final file = File(oldPath);
      if (!await file.exists()) return false;

      final extension = p.extension(oldPath);
      final newPath = p.join(p.dirname(oldPath), '$newNameWithoutExtension$extension');
      
      await file.rename(newPath);
      return true;
    } catch (e) {
      print('Error renaming song: $e');
      return false;
    }
  }

  /// Deletes a song file using Native MediaStore ID or direct file deletion.
  Future<bool> deleteSong(int id, String path) async {
    try {
      final bool result = await _channel.invokeMethod('deleteFile', {
        'id': id,
        'path': path,
      });
      return result;
    } catch (e) {
      print('Error deleting song: $e');
      return false;
    }
  }

  /// Opens the Android "All Files Access" settings page.
  Future<void> openManageStorageSettings() async {
    try {
      await _channel.invokeMethod('openManageStorageSettings');
    } catch (e) {
      print('Error opening storage settings: $e');
    }
  }

  /// Toggles a song's hidden status in Hive.
  Future<void> toggleHideSong(int songId) async {
    final box = Hive.box('hidden_songs_box');
    if (box.containsKey(songId)) {
      await box.delete(songId);
    } else {
      await box.put(songId, true);
    }
  }

  /// Checks if a song is hidden.
  bool isHidden(int songId) {
    return Hive.box('hidden_songs_box').containsKey(songId);
  }

  /// Sets a song as the system ringtone via Native MethodChannel.
  Future<bool> setAsRingtone(String path, String title) async {
    try {
      final bool result = await _channel.invokeMethod('setRingtone', {
        'path': path,
        'title': title,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to set ringtone: ${e.message}');
      return false;
    }
  }
}
