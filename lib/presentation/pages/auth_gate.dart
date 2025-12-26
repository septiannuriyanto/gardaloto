import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart' as cubit_auth;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cubit/auth_cubit.dart';
import 'login_page.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          context.go('/update-password');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, cubit_auth.AuthState>(
      listener: (context, state) {
        if (state is cubit_auth.AuthAuthenticated) {
          context.pushReplacement('/dashboard');
        }
      },
      builder: (context, state) {
        // If authenticated, the listener handles navigation.
        // For Unauthenticated, Loading, Error, etc., we show LoginPage.
        // This ensures the LoginPage state (text inputs) is preserved.

        if (state is cubit_auth.AuthAuthenticated) {
          // Should have navigated away, but if we are here, show loader
          return const Scaffold(
            body: AppBackground(
              child: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
          );
        }

        // For all other states (Unauthenticated, Loading, Error, etc.), show LoginPage
        // The LoginPage handles its own Loading state for the button.
        // We also handle displaying the error via SnackBar in the listener/builder.

        if (state is cubit_auth.AuthError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }

        return const LoginPage();
      },
    );
  }
}
