import 'package:flutter/material.dart';

/// Kam Kam Design System
/// Based on the logo: Green primary, Navy blue backgrounds, clean modern aesthetic
class AppTheme {
  AppTheme._();

  // ============================================================================
  // BRAND COLORS - Derived from Kam Kam Logo
  // ============================================================================
  
  // Primary brand green (from logo - muted/professional tone)
  static const Color primaryGreen = Color(0xFF5CB85C);       // Main brand green (muted)
  static const Color primaryGreenDark = Color(0xFF4A9D4A);   // Darker variant
  static const Color primaryGreenLight = Color(0xFF7BC67B);  // Lighter variant
  
  // Secondary white/cream (from logo text)
  static const Color brandWhite = Color(0xFFF8FAFC);
  
  // Navy blue backgrounds (from logo)
  static const Color navyDark = Color(0xFF0F172A);           // Darkest navy
  static const Color navyMedium = Color(0xFF1E293B);         // Medium navy
  static const Color navyLight = Color(0xFF334155);          // Light navy
  static const Color navyAccent = Color(0xFF475569);         // Accent navy
  
  // Semantic colors
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);
  
  // Match result colors
  static const Color winColor = Color(0xFF22C55E);
  static const Color drawColor = Color(0xFFF59E0B);
  static const Color lossColor = Color(0xFFEF4444);
  
  // Status badge colors
  static const Color activeStatus = Color(0xFF22C55E);
  static const Color draftStatus = Color(0xFF64748B);
  static const Color completedStatus = Color(0xFF3B82F6);
  
  // ============================================================================
  // DARK THEME - Primary theme (matches logo aesthetic)
  // ============================================================================
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: navyDark,
    
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      onPrimary: navyDark,
      primaryContainer: Color(0xFF166534),
      onPrimaryContainer: primaryGreenLight,
      secondary: Color(0xFF94A3B8),
      onSecondary: navyDark,
      secondaryContainer: navyLight,
      onSecondaryContainer: brandWhite,
      tertiary: infoBlue,
      onTertiary: Colors.white,
      surface: navyMedium,
      onSurface: brandWhite,
      surfaceContainerHighest: navyLight,
      error: errorRed,
      onError: Colors.white,
      outline: navyAccent,
      outlineVariant: navyLight,
    ),
    
    // Typography
    fontFamily: 'Inter',
    textTheme: _darkTextTheme,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: navyMedium,
      foregroundColor: brandWhite,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 2,
      surfaceTintColor: navyLight,
      titleTextStyle: TextStyle(
        color: brandWhite,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: navyMedium,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: navyLight, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    
    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: navyLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: navyAccent, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: navyAccent, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: const Color(0xFF94A3B8),
      suffixIconColor: const Color(0xFF94A3B8),
    ),
    
    // Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: navyDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Filled Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: navyDark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Icon Buttons
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF94A3B8),
      ),
    ),
    
    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: navyDark,
      elevation: 4,
      shape: CircleBorder(),
    ),
    
    // Dividers
    dividerTheme: const DividerThemeData(
      color: navyLight,
      thickness: 1,
      space: 1,
    ),
    
    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: navyLight,
      selectedColor: primaryGreen.withValues(alpha: 0.2),
      labelStyle: const TextStyle(
        color: brandWhite,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: navyAccent, width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    
    // Dialogs
    dialogTheme: DialogThemeData(
      backgroundColor: navyMedium,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: brandWhite,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        height: 1.5,
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: navyMedium,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // List Tiles
    listTileTheme: const ListTileThemeData(
      textColor: brandWhite,
      iconColor: Color(0xFF94A3B8),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    
    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navyMedium,
      indicatorColor: primaryGreen.withValues(alpha: 0.15),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryGreen, size: 24);
        }
        return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    
    // Tab Bar
    tabBarTheme: TabBarThemeData(
      labelColor: primaryGreen,
      unselectedLabelColor: const Color(0xFF94A3B8),
      indicatorColor: primaryGreen,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Progress Indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryGreen,
      linearTrackColor: navyLight,
      circularTrackColor: navyLight,
    ),
    
    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen;
        }
        return const Color(0xFF94A3B8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreen.withValues(alpha: 0.3);
        }
        return navyLight;
      }),
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: navyLight,
      contentTextStyle: const TextStyle(color: brandWhite, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    ),
  );
  
  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryGreenDark,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    
    colorScheme: const ColorScheme.light(
      primary: primaryGreenDark,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCFCE7),
      onPrimaryContainer: Color(0xFF166534),
      secondary: Color(0xFF64748B),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE2E8F0),
      onSecondaryContainer: Color(0xFF334155),
      tertiary: infoBlue,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFFF1F5F9),
      error: errorRed,
      onError: Colors.white,
      outline: Color(0xFFCBD5E1),
      outlineVariant: Color(0xFFE2E8F0),
    ),
    
    fontFamily: 'Inter',
    textTheme: _lightTextTheme,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    
    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreenDark, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: const Color(0xFF64748B),
      suffixIconColor: const Color(0xFF64748B),
    ),
    
    // Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Filled Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreenDark,
        side: const BorderSide(color: primaryGreenDark, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    
    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreenDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Icon Buttons
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
      ),
    ),
    
    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreenDark,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    
    // Dividers
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: 1,
    ),
    
    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: primaryGreenDark.withValues(alpha: 0.15),
      labelStyle: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    
    // Dialogs
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        height: 1.5,
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // List Tiles
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFF0F172A),
      iconColor: Color(0xFF64748B),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    
    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primaryGreenDark.withValues(alpha: 0.12),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryGreenDark, size: 24);
        }
        return const IconThemeData(color: Color(0xFF64748B), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primaryGreenDark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    
    // Tab Bar
    tabBarTheme: TabBarThemeData(
      labelColor: primaryGreenDark,
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: primaryGreenDark,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Progress Indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryGreenDark,
      linearTrackColor: Color(0xFFE2E8F0),
      circularTrackColor: Color(0xFFE2E8F0),
    ),
    
    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreenDark;
        }
        return const Color(0xFF94A3B8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryGreenDark.withValues(alpha: 0.3);
        }
        return const Color(0xFFE2E8F0);
      }),
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF334155),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    ),
  );
  
  // ============================================================================
  // TEXT THEMES
  // ============================================================================
  
  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      color: brandWhite,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      color: brandWhite,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      color: brandWhite,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineLarge: TextStyle(
      color: brandWhite,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      color: brandWhite,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    headlineSmall: TextStyle(
      color: brandWhite,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      color: brandWhite,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      color: brandWhite,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      color: brandWhite,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: brandWhite,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      color: brandWhite,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      color: Color(0xFF64748B),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
  );
  
  static const TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    headlineSmall: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      color: Color(0xFF64748B),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF334155),
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF64748B),
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      color: Color(0xFF64748B),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.4,
    ),
  );
}

/// Extension for easy access to brand colors
extension BrandColors on ColorScheme {
  Color get success => AppTheme.successGreen;
  Color get warning => AppTheme.warningAmber;
  Color get win => AppTheme.winColor;
  Color get draw => AppTheme.drawColor;
  Color get loss => AppTheme.lossColor;
}
