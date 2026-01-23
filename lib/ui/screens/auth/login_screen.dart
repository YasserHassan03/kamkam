import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';

/// Modern login screen for admin authentication
class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const LoginScreen({
    super.key,
    this.redirectTo,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isHandlingError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('LoginScreen: Starting login attempt');
    
    final result = await ref.read(authNotifierProvider.notifier).signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    debugPrint('LoginScreen: Login result received');
      
      result.fold(
        (error) {
          debugPrint('LoginScreen: Login error - $error');
          
          // Use global navigator key to show dialog even if widget is unmounted
          // This ensures the error dialog appears even if the router redirects
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigatorState = globalNavigatorKey.currentState;
            if (navigatorState != null) {
              try {
                final navigatorContext = navigatorState.context;
                if (navigatorContext.mounted) {
                  showDialog(
                    context: navigatorContext,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(navigatorContext).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Text('Login Failed'),
                        ],
                      ),
                      content: Text(error),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  debugPrint('LoginScreen: Error dialog shown via global navigator');
                }
              } catch (e) {
                debugPrint('LoginScreen: Error showing dialog via global navigator: $e');
              }
            } else {
              debugPrint('LoginScreen: Global navigator key currentState is null');
            }
          });
          // DO NOT navigate - stay on login screen
        },
      (user) {
        // Only navigate on success
        // Router will handle redirect based on user profile status
        // Check if widget is still mounted before navigating
        if (!mounted) {
          debugPrint('LoginScreen: Widget unmounted, router will handle redirect automatically');
          // Router will automatically redirect based on auth state change
          return;
        }
        
        try {
          if (widget.redirectTo != null && !widget.redirectTo!.contains('error=')) {
            context.go(widget.redirectTo!);
          } else {
            // Let router decide based on profile
            context.go('/');
          }
        } catch (e) {
          debugPrint('LoginScreen: Error navigating after login: $e');
          // Router will handle redirect automatically based on auth state
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Check for error parameter in URL
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Add a key to prevent router from replacing this scaffold
      key: const ValueKey('login_screen'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F1419),
                    const Color(0xFF1A1F2B).withValues(alpha: 0.8),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFFAFCFF),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.sports_soccer_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tournament Management',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Admin Login',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to manage your tournaments',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 28),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'admin@example.com',
                              prefixIcon: const Icon(Icons.email_rounded),
                              prefixIconColor: Theme.of(context).colorScheme.primary,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              prefixIconColor: Theme.of(context).colorScheme.primary,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword 
                                    ? Icons.visibility_rounded 
                                    : Icons.visibility_off_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Login Button
                          FilledButton(
                            onPressed: isLoading ? null : _handleLogin,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Create Account'),
                      ),
                    ],
                  ),

                  // Back Button
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

