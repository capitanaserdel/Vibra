import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

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

  Future<LyricData?> getLyrics(String trackName, String artistName, {String? albumName, int? durationSeconds}) async {
    final cacheKey = '${trackName}_$artistName'.toLowerCase().replaceAll(' ', '_');
    
    // Check local storage first
    if (_box.containsKey(cacheKey)) {
      final cached = _box.get(cacheKey);
      return LyricData.fromJson(Map<String, dynamic>.from(cached));
    }

    // Fetch from API
    try {
      final queryParams = {
        'track_name': trackName,
        'artist_name': artistName,
        if (albumName != null) 'album_name': albumName,
        if (durationSeconds != null) 'duration': durationSeconds.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/get').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lyricData = LyricData(
          plainLyrics: data['plainLyrics'],
          syncedLyrics: data['syncedLyrics'],
          source: 'lrclib',
        );
        
        // Save to cache
        await _box.put(cacheKey, lyricData.toJson());
        return lyricData;
      }
    } catch (e) {
      print("Error fetching lyrics: $e");
    }
    
    return null;
  }
}
