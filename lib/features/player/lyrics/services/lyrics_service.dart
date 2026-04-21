import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:music/core/utils/metadata_helper.dart';

class LyricData {
  final String? plainLyrics;
  final String? syncedLyrics;
  final String source;

  LyricData({this.plainLyrics, this.syncedLyrics, required this.source});

  Map<String, dynamic> toJson() => {
        'plainLyrics': plainLyrics,
        'syncedLyrics': syncedLyrics,
        'source': source,
      };

  factory LyricData.fromJson(Map<String, dynamic> json) => LyricData(
        plainLyrics: json['plainLyrics'],
        syncedLyrics: json['syncedLyrics'],
        source: json['source'] ?? 'api',
      );
}

class LyricsService {
  final Box _box = Hive.box('lyrics_box');
  static const String baseUrl = 'https://lrclib.net/api';

  Future<LyricData?> getLyrics(
    String trackName, 
    String artistName, {
    String? albumName, 
    int? durationSeconds,
    String? customTrackName,
    String? customArtistName,
  }) async {
    // If user provided a custom search, bypass automated logic for the request
    final searchTrack = customTrackName ?? trackName;
    final searchArtist = customArtistName ?? artistName;

    // Standardized cache key
    final cacheKey = 'lyrics_${MetadataHelper.normalize(searchTrack)}_${MetadataHelper.normalize(searchArtist)}';
    
    // Check local storage first
    if (_box.containsKey(cacheKey)) {
      final cached = _box.get(cacheKey);
      return LyricData.fromJson(Map<String, dynamic>.from(cached));
    }

    final headers = {
      'User-Agent': 'Vibra Music Player/1.0.0 (https://github.com/capitanaserdel/Vibra)',
    };

    // Stage 1: Soft Clean / Precise Signature
    // Use stripNoise to keep case/punctuation but remove suffixes
    final softTitle = MetadataHelper.stripNoise(searchTrack);
    final softArtist = MetadataHelper.getMainArtist(searchArtist);

    try {
      final uri = Uri.parse('$baseUrl/get').replace(queryParameters: {
        'track_name': softTitle,
        'artist_name': softArtist,
        if (albumName != null) 'album_name': albumName,
      });
      
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return _processAndCache(cacheKey, json.decode(response.body));
      }
    } catch (_) {}

    // Stage 2: Normalized Search (Fallback if Soft Clean failed)
    final normTitle = MetadataHelper.normalize(searchTrack);
    final normArtist = MetadataHelper.normalize(searchArtist);
    
    try {
      final uri = Uri.parse('$baseUrl/get').replace(queryParameters: {
        'track_name': normTitle,
        'artist_name': normArtist,
      });
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return _processAndCache(cacheKey, json.decode(response.body));
      }
    } catch (_) {}

    // Stage 3: Broad Search (Final Fallback)
    try {
      final searchUri = Uri.parse('$baseUrl/search').replace(queryParameters: {
        'track_name': softTitle,
        'artist_name': softArtist,
      });
      final response = await http.get(searchUri, headers: headers);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) return _processAndCache(cacheKey, results.first);
      }
    } catch (_) {}
    
    return null;
  }

  Future<LyricData> _processAndCache(String key, Map<String, dynamic> data) async {
    final lyricData = LyricData(
      plainLyrics: data['plainLyrics'],
      syncedLyrics: data['syncedLyrics'],
      source: 'lrclib',
    );
    await _box.put(key, lyricData.toJson());
    return lyricData;
  }
}
