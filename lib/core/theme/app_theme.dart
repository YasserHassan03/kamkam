import 'package:flutter/material.dart';

/// App theme configuration - Modern sports app design
class AppTheme {
  AppTheme._();

  // ============================================================================
  // MODERN VIBRANT COLOR PALETTE - Sports Theme
  // ============================================================================
  
  // Primary colors - Vibrant green for sports energy
  static const Color primaryColor = Color(0xFF00D981);      // Bright sports green
  static const Color primaryDark = Color(0xFF00A359);       // Deep green
  static const Color primaryLight = Color(0xFF66E8A3);      // Light green
  
  // Secondary/Accent colors
  static const Color accentColor = Color(0xFFFF6B35);       // Vibrant orange
  static const Color accentLight = Color(0xFFFFB84D);       // Light orange
  
  // Status colors - Modern palette
  static const Color errorColor = Color(0xFFFF3B4A);        // Modern red
  static const Color successColor = Color(0xFF00D981);      // Match primary
  static const Color warningColor = Color(0xFFFFB84D);      // Warm orange
  
  // Dark theme background colors - Modern dark palette
  static const Color darkBackground = Color(0xFF0F1419);    // Darker background
  static const Color darkSurface = Color(0xFF1A1F2B);       // Modern surface
  static const Color darkCard = Color(0xFF252D3D);          // Better contrast
  static const Color darkDivider = Color(0xFF3A4255);       // Modern divider
  
  // Light theme background colors
  static const Color lightBackground = Color(0xFFFAFCFF);   // Modern light bg
  static const Color lightSurface = Color(0xFFFFFFFF);      // Clean white
  static const Color lightCard = Color(0xFFFBFEFF);         // Subtle tone
  
  // Text colors
  static const Color textPrimaryDark = Color(0xFFFCFDFF);   // Pure bright white
  static const Color textSecondaryDark = Color(0xFF98A3B5); // Modern gray
  static const Color textPrimaryLight = Color(0xFF0F1419);  // Dark text
  static const Color textSecondaryLight = Color(0xFF6B7580); // Modern gray

  // Match result colors - Sports themed
  static const Color winColor = Color(0xFF00D981);          // Green win
  static const Color drawColor = Color(0xFFFFB84D);         // Orange draw
  static const Color lossColor = Color(0xFFFF3B4A);         // Red loss
  
  // Team colors palette
  static const List<Color> teamColorPalette = [
    Color(0xFF00D981),  // Green
    Color(0xFF3366FF),  // Blue
    Color(0xFFFF6B35),  // Orange
    Color(0xFFFFD700),  // Gold
    Color(0xFF9D4EDD),  // Purple
    Color(0xFF00B4DB),  // Cyan
    Color(0xFFE63946),  // Red
    Color(0xFF1D7874),  // Teal
  ];

  /// Dark theme (modern sports app)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: darkSurface,
      error: errorColor,
      onPrimary: Color(0xFF0F1419),
      onSecondary: Colors.white,
      onSurface: textPrimaryDark,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: textPrimaryDark,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkDivider, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkDivider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
      hintStyle: const TextStyle(color: textSecondaryDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: textSecondaryDark,
      suffixIconColor: textSecondaryDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFF0F1419),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFF0F1419),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Color(0xFF0F1419),
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
      space: 16,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: primaryColor.withValues(alpha: 0.15),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor, size: 26);
        }
        return const IconThemeData(color: textSecondaryDark, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: textSecondaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkCard,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: const TextStyle(
        color: textPrimaryDark,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkDivider),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkCard,
      contentTextStyle: const TextStyle(color: textPrimaryDark, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: textSecondaryDark,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimaryDark,
      iconColor: textSecondaryDark,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textPrimaryDark,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        color: textPrimaryDark,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: textPrimaryDark,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: TextStyle(
        color: textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: textPrimaryDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        color: textPrimaryDark,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textPrimaryDark,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textPrimaryDark,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: textPrimaryDark,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: textPrimaryDark,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: textPrimaryDark,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: textSecondaryDark,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: primaryColor,
      textTheme: ButtonTextTheme.primary,
    ),
  );

  /// Light theme (modern sports app)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: lightSurface,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryLight,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: textSecondaryLight,
      suffixIconColor: textSecondaryLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
      space: 16,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: primaryColor.withValues(alpha: 0.15),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor, size: 26);
        }
        return IconThemeData(color: Colors.grey.shade600, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: const TextStyle(
        color: textPrimaryLight,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimaryLight,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: textPrimaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: textSecondaryLight,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimaryLight,
      iconColor: textSecondaryLight,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textPrimaryLight,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: TextStyle(
        color: textPrimaryLight,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: textPrimaryLight,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: TextStyle(
        color: textPrimaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: textPrimaryLight,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        color: textPrimaryLight,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textPrimaryLight,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textPrimaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: textSecondaryLight,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: textPrimaryLight,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: textPrimaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: textSecondaryLight,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: textPrimaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: textSecondaryLight,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: textSecondaryLight,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: primaryColor,
      textTheme: ButtonTextTheme.primary,
    ),
  );
}
