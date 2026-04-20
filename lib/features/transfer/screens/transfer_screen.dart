import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/transfer/services/transfer_service.dart';

final transferServiceProvider = Provider((ref) => TransferService());
final ipAddressProvider = FutureProvider<String?>((ref) => ref.watch(transferServiceProvider).getIPAddress());

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  bool _isServerRunning = false;
  String? _lastUploadedFile;

  void _toggleServer() async {
    final service = ref.read(transferServiceProvider);
    if (_isServerRunning) {
      await service.stopServer();
      setState(() => _isServerRunning = false);
    } else {
      await service.startServer((fileName) {
        setState(() => _lastUploadedFile = fileName);
      });
      setState(() => _isServerRunning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ipAddress = ref.watch(ipAddressProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('WiFi Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isServerRunning ? Icons.wifi_tethering_rounded : Icons.portable_wifi_off_rounded,
                size: 100,
                color: _isServerRunning ? const Color(0xFF39FF14) : Colors.white24,
              ),
              const SizedBox(height: 30),
              
              if (_isServerRunning) ...[
                const Text('Server is active!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ipAddress.when(
                  data: (ip) => Text(
                    'Open this in your browser:\nhttp://$ip:8080',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF39FF14), fontSize: 18),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => const Text('Error getting IP Address'),
                ),
              ] else ...[
                const Text('Start transfer server to upload files from your computer', textAlign: TextAlign.center),
              ],
              
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _toggleServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServerRunning ? Colors.redAccent : const Color(0xFF39FF14),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(_isServerRunning ? 'Stop Server' : 'Start Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              
              if (_lastUploadedFile != null) ...[
                const SizedBox(height: 40),
                Text('Last uploaded: $_lastUploadedFile', style: const TextStyle(color: Colors.white54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
