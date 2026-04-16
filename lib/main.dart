import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/features/audio/handler/music_audio_handler.dart';
import 'package:music/features/ui/screens/home_screen.dart';

late MusicAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for lyrics
  await Hive.initFlutter();
  await Hive.openBox('lyrics_box');
  await Hive.openBox('settings_box');

  // Initialize Audio Service
  audioHandler = await AudioService.init(
    builder: () => MusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: MusicApp(),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39FF14),
          brightness: Brightness.dark,
          primary: const Color(0xFF39FF14),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
      ),
      home: const HomeScreen(),
    );
  }
}
