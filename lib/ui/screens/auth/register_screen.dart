import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../../data/models/user_profile.dart';
import '../../../core/constants/app_constants.dart';

/// Registration screen for new admin accounts
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      result.fold(
        (error) {
          setState(() => _isSubmitting = false);
          
          // Show detailed error dialog for sign-up failures
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
              title: const Text('Sign Up Failed'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
                if (error.contains('profile setup failed') || error.contains('database'))
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Show instructions
                      showDialog(
                        context: context,
                        builder: (ctx2) => AlertDialog(
                          title: const Text('Troubleshooting'),
                          content: const Text(
                            'If sign-up keeps failing:\n\n'
                            '1. Check your internet connection\n'
                            '2. Verify the database trigger is working\n'
                            '3. Contact an administrator\n\n'
                            'Your account may have been created in Supabase Auth even if the profile failed.'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx2).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Get Help'),
                  ),
              ],
            ),
          );
        },
        (user) async {
          setState(() => _isSubmitting = false);
          
          // Wait for profile to be created by database trigger
          // Poll for profile up to 10 times (5 seconds total)
          UserProfile? profile;
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (!mounted) return;
            
            // Invalidate and try to get profile
            ref.invalidate(currentUserProfileProvider);
            try {
              profile = await ref.read(currentUserProfileProvider.future);
              if (profile != null) {
                break; // Profile found, exit loop
              }
            } catch (e) {
              // Continue polling
            }
          }
          
          if (!mounted) return;
          
          // Redirect to pending approval screen
          // The router will handle showing the pending screen based on profile status
          context.go('/pending-approval');
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading || _isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo/Icon
                      Icon(
                        Icons.person_add,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Join ${AppConstants.appName}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account to manage your tournaments',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
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
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleRegister(),
                      ),
                      const SizedBox(height: 24),

                      // Register Button
                      FilledButton(
                        onPressed: isLoading ? null : _handleRegister,
                        child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Account'),
                      ),
                      const SizedBox(height: 16),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?'),
                          TextButton(
                            onPressed: isLoading ? null : () => context.go('/login'),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
