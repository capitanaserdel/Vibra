import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileManagementService {
  static const _channel = MethodChannel('com.example.vibra/file_management');

  /// Gets the public Vibra music download directory: /storage/emulated/0/Music/Vibra
  Future<Directory?> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory == null) return null;
        final rootPath = directory.path.split('/Android/data/').first;
        return Directory(p.join(rootPath, 'Music', 'Vibra'));
      } else {
        final directory = await getApplicationDocumentsDirectory();
        return Directory(p.join(directory.path, 'Vibra'));
      }
    } catch (e) {
      print('Error getting download directory: $e');
      return null;
    }
  }

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
  /// Returns true on success, false on failure, and null if the user cancelled the request.
  Future<bool?> deleteSong(int id, String path, String? uri) async {
    try {
      final bool result = await _channel.invokeMethod('deleteFile', {
        'id': id,
        'path': path,
        'uri': uri,
      });
      return result;
    } on PlatformException catch (e) {
      print('PlatformException deleting song: ${e.code} - ${e.message}');
      if (e.code == 'CANCELLED') {
        return null;
      }
      return false;
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

  /// Explicitly hides a song in Hive.
  Future<void> hideSong(int songId) async {
    await Hive.box('hidden_songs_box').put(songId, true);
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
