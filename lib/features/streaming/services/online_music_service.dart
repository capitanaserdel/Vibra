import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class OnlineStation {
  final String uuid;
  final String name;
  final String url;
  final String favicon;
  final String tags;

  OnlineStation({
    required this.uuid,
    required this.name,
    required this.url,
    required this.favicon,
    required this.tags,
  });

  factory OnlineStation.fromJson(Map<String, dynamic> json) {
    return OnlineStation(
      uuid: json['stationuuid'] ?? '',
      name: json['name'] ?? 'Unknown Station',
      url: json['url_resolved'] ?? json['url'] ?? '',
      favicon: json['favicon'] ?? '',
      tags: json['tags'] ?? '',
    );
  }
}

class OnlineMusicService {
  // Use a list of stable mirrors as a fallback mechanism
  static const List<String> serverMirrors = [
    'de1.api.radio-browser.info',
    'fr1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];

  String _currentBaseUrl = 'https://de1.api.radio-browser.info/json';
  final Random _random = Random();

  void _rotateServer() {
    final server = serverMirrors[_random.nextInt(serverMirrors.length)];
    _currentBaseUrl = 'https://$server/json';
  }

  Map<String, String> get _headers => {
    'User-Agent': 'AntigravityMusic/1.0',
    'Accept': 'application/json',
  };

  Future<List<OnlineStation>> searchStations(String query) async {
    for (int i = 0; i < 3; i++) {
      try {
        final response = await http.get(
          Uri.parse('$_currentBaseUrl/stations/search?name=${Uri.encodeComponent(query)}&limit=20'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => OnlineStation.fromJson(json)).toList();
        }
      } catch (e) {
        print("Error searching stations (try ${i+1}): $e");
        _rotateServer(); // Pick a different mirror on failure
      }
    }
    return [];
  }

  Future<List<OnlineStation>> getPopularStations() async {
    for (int i = 0; i < 3; i++) {
      try {
        final response = await http.get(
          Uri.parse('$_currentBaseUrl/stations/topclick?limit=20'),
          headers: _headers,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => OnlineStation.fromJson(json)).toList();
        }
      } catch (e) {
        print("Error fetching popular stations (try ${i+1}): $e");
        _rotateServer(); // Pick a different mirror on failure
      }
    }
    return [];
  }

  Future<List<OnlineTrack>> searchSongs(String query) async {
    try {
      final response = await http.get(
        Uri.parse('https://jiosaavn-api-beta.vercel.app/search/songs?query=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent': 'AntigravityMusic/1.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['status'] == 'SUCCESS' && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          final List<dynamic> list = data['results'] ?? [];
          return list.map((json) => OnlineTrack.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print("Error searching songs: $e");
    }
    return [];
  }
}

class OnlineTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String previewUrl;
  final int duration;

  OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.previewUrl,
    required this.duration,
  });

  factory OnlineTrack.fromJson(Map<String, dynamic> json) {
    final imageList = json['image'] as List<dynamic>? ?? [];
    String coverUrl = '';
    if (imageList.isNotEmpty) {
      coverUrl = imageList.last['link'] ?? '';
    }

    final downloadUrlList = json['downloadUrl'] as List<dynamic>? ?? [];
    String previewUrl = '';
    if (downloadUrlList.isNotEmpty) {
      previewUrl = downloadUrlList.last['link'] ?? '';
    }

    final albumMap = json['album'] as Map<String, dynamic>? ?? {};
    final albumName = albumMap['name'] ?? 'Unknown Album';

    return OnlineTrack(
      id: json['id']?.toString() ?? '',
      title: json['name'] ?? 'Unknown Title',
      artist: json['primaryArtists'] ?? 'Unknown Artist',
      album: albumName,
      coverUrl: coverUrl,
      previewUrl: previewUrl,
      duration: int.tryParse(json['duration']?.toString() ?? '') ?? 0,
    );
  }
}
