import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TransferService {
  HttpServer? _server;
  final _info = NetworkInfo();

  Future<String?> getIPAddress() async {
    return await _info.getWifiIP();
  }

  Future<void> startServer(Function(String) onFileReceived) async {
    final router = Router();

    // Serve HTML Interface
    router.get('/', (Request request) {
      return Response.ok(
        _htmlInterface,
        headers: {'content-type': 'text/html'},
      );
    });

    // Handle Upload
    router.post('/upload', (Request request) async {
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response.forbidden('Expected multipart/form-data');
      }

      // Basic multipart parsing (simplified for MVP)
      // For a robust implementation, use 'shelf_multipart'
      // But for small files/demonstration, we'll assume a single file field
      
      final bytes = await request.read().expand((b) => b).toList();
      final directory = await getExternalStorageDirectory();
      final musicDir = Directory(p.join(directory!.path, 'Vibra', 'music'));
      
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final label = 'Uploaded_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File(p.join(musicDir.path, label));
      await file.writeAsBytes(bytes);

      onFileReceived(label);
      return Response.ok('File Uploaded Successfully!');
    });

    _server = await io.serve(router, InternetAddress.anyIPv4, 8080);
    print('Server running on ${_server!.address.address}:${_server!.port}');
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  final String _htmlInterface = '''
<!DOCTYPE html>
<html>
<head>
    <title>Vibra WiFi Transfer</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: sans-serif; background: #0B0B0B; color: white; text-align: center; padding: 50px; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 20px; display: inline-block; border: 1px solid #39FF14; }
        h1 { color: #39FF14; }
        input[type="file"] { margin: 20px 0; }
        button { background: #39FF14; color: black; border: none; padding: 10px 20px; border-radius: 10px; font-weight: bold; cursor: pointer; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Vibra Transfer</h1>
        <p>Select a music file to upload to your phone.</p>
        <form action="/upload" method="post" enctype="multipart/form-data">
            <input type="file" name="file" accept="audio/*"><br>
            <button type="submit">Upload Now</button>
        </form>
    </div>
</body>
</html>
''';
}
