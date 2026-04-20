import 'dart:io';
import 'package:crypto/crypto.dart';

class HashHelper {
  static Future<String> computeFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return "";
    
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  static String computeStringHash(String input) {
    return sha256.convert(input.codeUnits).toString();
  }
}
