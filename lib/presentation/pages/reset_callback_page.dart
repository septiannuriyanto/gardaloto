import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';

class ResetCallbackPage extends StatefulWidget {
  final String? error;
  final String? errorDescription;

  const ResetCallbackPage({
    super.key,
    this.error,
    this.errorDescription,
  });

  @override
  State<ResetCallbackPage> createState() => _ResetCallbackPageState();
}

class _ResetCallbackPageState extends State<ResetCallbackPage> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Check for errors first
    if (widget.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog();
      });
      return; 
    }

    // Listen for the recovery event.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          context.go('/update-password');
        }
      }
    }, onError: (error) {
      // Handle stream errors (e.g. otp_expired)
      if (mounted) {
         // We can choose to show dialog here if we didn't get error params from URL
         // But usually URL params are present for this error.
         // Just logging/suppressing to ensure no crash here.
         debugPrint('Auth subscription error: $error');
         
         // If we are here, likely the token exchange failed.
         // Force a dialog if one isn't already showing?
         if (widget.error == null) {
            // Manually trigger error dialog logic if not already triggered by URL
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 _showErrorDialogWithCustomMessage('Link expired or invalid.');
             });
         }
      }
    });
  }

  void _showErrorDialogWithCustomMessage(String msg) {
      showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Link'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.go('/'); // Go to login
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Link'),
        content: Text(
          widget.errorDescription?.replaceAll('+', ' ') ?? 
          'The password reset link is invalid or has expired. Please request a new one.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.go('/'); // Go to login
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // _authSubscription might not be initialized if error exists
    if (widget.error == null) {
      _authSubscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackground(
        child: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}
