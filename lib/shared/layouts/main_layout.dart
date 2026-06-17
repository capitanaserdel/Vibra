import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/streaming/screens/radio_screen.dart';
import 'package:music/features/library/screens/library_screen.dart';
import 'package:music/features/library/screens/home_content_screen.dart';
import 'package:music/features/search/screens/search_screen.dart';
import 'package:music/features/creator/screens/create_screen.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:music/shared/widgets/mini_player.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const LibraryScreen(),
    const HomeContentScreen(),
    const SearchScreen(),
    const RadioScreen(),
    const CreateScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bgPath = settings.appBackgroundImagePath;
    final hasImage = bgPath.isNotEmpty && File(bgPath).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── App background image layer ──────────────────────────
        if (hasImage)
          Positioned.fill(
            child: Image.file(
              File(bgPath),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        if (hasImage)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: settings.appBackgroundBlur,
                sigmaY: settings.appBackgroundBlur,
              ),
              child: Container(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black.withOpacity(0.3),
              ),
            ),
          ),

        // ── Main app scaffold ───────────────────────────────────
        Scaffold(
          backgroundColor: hasImage ? Colors.transparent : null,
          extendBody: true,
          body: _pages[_currentIndex],
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) => setState(() => _currentIndex = index),
                      backgroundColor: hasImage
                          ? Colors.black.withOpacity(0.3)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                      elevation: 0,
                      selectedItemColor: Theme.of(context).colorScheme.primary,
                      unselectedItemColor:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      showSelectedLabels: true,
                      showUnselectedLabels: false,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.library_music_rounded),
                          label: 'Library',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search_rounded),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.radio_rounded),
                          label: 'Radio',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.add_circle_outline_rounded),
                          label: 'Create',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
