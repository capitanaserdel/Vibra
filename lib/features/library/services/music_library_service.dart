import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicLibraryService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> requestPermission() async {
    if (await Permission.audio.request().isGranted ||
        await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  Future<List<SongModel>> fetchLocalSongs() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    return await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }

  Future<List<AlbumModel>> fetchAlbums() async {
    return await _audioQuery.queryAlbums();
  }
}
