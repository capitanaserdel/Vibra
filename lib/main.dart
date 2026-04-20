import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/features/player/handler/music_audio_handler.dart';
import 'package:music/shared/layouts/main_layout.dart';
import 'package:music/core/theme/app_theme.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:firebase_core/firebase_core.dart';

late MusicAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Requires google-services.json / GoogleService-Info.plist)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase initialization failed: $e. Ensure config files are present.");
  }

  // Initialize Hive for lyrics
  await Hive.initFlutter();
  await Hive.openBox('lyrics_box');
  await Hive.openBox('settings_box');
  await Hive.openBox('play_history_box');
  await Hive.openBox('metadata_box');
  await Hive.openBox('hidden_songs_box');

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

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    return MaterialApp(
      title: 'Vibra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.generateTheme(settings),
      home: const MainLayout(),
    );
  }
}
