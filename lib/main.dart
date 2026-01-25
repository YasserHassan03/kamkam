import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  // Catch all errors to prevent red screen
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Suppress all Flutter errors - no red screen ever
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        // Just print to console in debug mode
        debugPrint('Flutter error: ${details.exceptionAsString()}');
      }
    };

    // Replace error widget with transparent container
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const SizedBox.shrink();
    };

    // Initialize Supabase
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );

    runApp(
      const ProviderScope(
        child: KamKamApp(),
      ),
    );
  }, (error, stackTrace) {
    // Catch any uncaught errors - just log them
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
    }
  });
}

class KamKamApp extends ConsumerWidget {
  const KamKamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
