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

  Future<List<ArtistModel>> fetchArtists() async {
    return await _audioQuery.queryArtists();
  }

  // Folders are typically queried as albums or by parsing device paths.
  // on_audio_query doesn't have a direct "queryFolders" but we can get all songs 
  // and group them by folder path in the provider.
}
