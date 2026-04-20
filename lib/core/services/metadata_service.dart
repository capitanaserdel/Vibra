import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';

class MetadataService {
  /// Reads metadata for a song file.
  Future<Tag?> readTags(String path) async {
    try {
      return await AudioTags.read(path);
    } catch (e) {
      print('Error reading tags: $e');
      return null;
    }
  }

  /// Updates metadata tags for a song file.
  Future<bool> updateTags(String path, {
    String? title,
    String? artist,
    String? album,
    int? year,
    String? genre,
  }) async {
    try {
      final tag = Tag(
        title: title,
        trackArtist: artist,
        album: album,
        year: year,
        genre: genre,
        pictures: [], // Required field
      );
      await AudioTags.write(path, tag);
      return true;
    } catch (e) {
      print('Error updating tags: $e');
      return false;
    }
  }

  /// Updates the embedded album art of a song file.
  Future<bool> updateCover(String path, Uint8List imageBytes) async {
    try {
      final tag = Tag(
        pictures: [
          Picture(
            bytes: imageBytes,
            mimeType: MimeType.png, // Enum type
            pictureType: PictureType.coverFront, // Correct enum name
          ),
        ],
      );
      await AudioTags.write(path, tag);
      return true;
    } catch (e) {
      print('Error updating cover: $e');
      return false;
    }
  }
}
