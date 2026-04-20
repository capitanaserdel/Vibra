import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/features/settings/providers/settings_provider.dart';

class AppTheme {
  static const Map<String, Color> accentPresets = {
    'Green': Color(0xFF39FF14),
    'Blue': Color(0xFF00E5FF),
    'Purple': Color(0xFFD500F9),
    'Orange': Color(0xFFFF6D00),
  };

  static ThemeData generateTheme(SettingsState settings) {
    final bool isLight = settings.themeMode == 'Light';
    final bool isAmoled = settings.themeMode == 'AMOLED';
    final Color primaryColor = accentPresets[settings.accentColor] ?? accentPresets['Green']!;

    final ColorScheme colorScheme = isLight
        ? ColorScheme.light(
            primary: primaryColor,
            secondary: primaryColor,
            surface: Colors.white,
            background: const Color(0xFFF8F8F8), // Subtle off-white
            onPrimary: Colors.black,
            onSurface: Colors.black,
            onBackground: Colors.black87,
            surfaceVariant: const Color(0xFFEEEEEE),
            outline: Colors.black12,
          )
        : ColorScheme.dark(
            primary: primaryColor,
            secondary: primaryColor,
            surface: isAmoled ? Colors.black : const Color(0xFF1E1E1E),
            background: isAmoled ? Colors.black : const Color(0xFF0B0B0B),
            onPrimary: Colors.black,
            onSurface: Colors.white,
            onBackground: Colors.white,
            surfaceVariant: const Color(0xFF2A2A2A),
            outline: Colors.white10,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      primaryColor: primaryColor,
      
      // Text Theme centralization
      textTheme: GoogleFonts.outfitTextTheme(
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
      ).apply(
        bodyColor: colorScheme.onBackground,
        displayColor: colorScheme.onBackground,
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        titleTextStyle: TextStyle(
          color: colorScheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primaryColor,
        unselectedItemColor: colorScheme.onBackground.withOpacity(0.4),
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: colorScheme.outline,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
        trackHeight: 4,
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
      ),
    );
  }

  // Unified Glassmorphic utility using semantic colors
  static BoxDecoration glassDecoration(BuildContext context, {
    double blur = 10.0,
    BorderRadius? borderRadius,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    return BoxDecoration(
      color: theme.colorScheme.surface.withOpacity(isLight ? 0.7 : 0.1),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
    );
  }
}
