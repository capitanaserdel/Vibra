class MetadataHelper {
  /// Cleans and formats song metadata based on PRD requirements.
  static String cleanMetadata(String? title, String? fileName) {
    // 1. Return title if it exists and isn't empty
    if (title != null && title.isNotEmpty) {
      return title;
    }

    // 2. Fallback to filename
    if (fileName == null || fileName.isEmpty) {
      return "Unknown Track";
    }

    String result = fileName;

    // Remove file extension (e.g., .mp3, .wav)
    result = result.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    // Remove underscores
    result = result.replaceAll('_', ' ');

    // Remove numbering at the start (e.g., "01 - ", "1. ", "01. ")
    result = result.replaceFirst(RegExp(r'^\d+[\s.-]+'), '');

    // Trim whitespace
    result = result.trim();

    return result.isEmpty ? "Unknown Track" : result;
  }

  static String cleanArtist(String? artist) {
    if (artist == null || artist.isEmpty || artist == "<unknown>") {
      return "Unknown Artist";
    }
    return artist.trim();
  }

  /// Normalizes a string for robust indexing and searching (lowercase, trim, strip special chars)
  static String normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters except alphanumeric and spaces
        .replaceAll(RegExp(r'\s+'), ' '); // Collapse multiple spaces
  }

  /// Extracts the main artist for cleaner searching (e.g., "Wizkid ft. Tems" -> "Wizkid")
  static String getMainArtist(String? artist) {
    if (artist == null || artist.isEmpty || artist == "<unknown>") {
      return "Unknown Artist";
    }

    String result = artist;

    // Split on common collaboration markers: " ft. ", " feat. ", " & ", " , "
    final markers = [
      RegExp(r'\s+ft\.?\s+', caseSensitive: false),
      RegExp(r'\s+feat\.?\s+', caseSensitive: false),
      RegExp(r'\s+&\s+'),
      RegExp(r'\s*,\s*'),
    ];

    for (final marker in markers) {
      if (result.contains(marker)) {
        result = result.split(marker).first;
      }
    }

    return result.trim();
  }

  /// Removes common "noise" from titles (Official Video, [HD], etc.) 
  /// but preserves case and internal punctuation for more accurate API hits.
  static String stripNoise(String input) {
    if (input.isEmpty) return input;
    
    String result = input;

    // Common suffixes to remove
    final noisePatterns = [
      RegExp(r'\(Official.*?\)', caseSensitive: false),
      RegExp(r'\[.*?HD.*?\]', caseSensitive: false),
      RegExp(r'\[.*?HQ.*?\]', caseSensitive: false),
      RegExp(r'\(Lyric.*?\)', caseSensitive: false),
      RegExp(r'\(Music Video\)', caseSensitive: false),
      RegExp(r'\(Explicit\)', caseSensitive: false),
      RegExp(r'\[Explicit\]', caseSensitive: false),
      RegExp(r'\(Video\)', caseSensitive: false),
      RegExp(r'feat\..*$', caseSensitive: false),
      RegExp(r'ft\..*$', caseSensitive: false),
    ];

    for (final pattern in noisePatterns) {
      result = result.replaceAll(pattern, '');
    }

    // Collapse spaces and trim
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
