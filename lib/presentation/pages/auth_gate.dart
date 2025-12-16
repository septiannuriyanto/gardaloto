import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:go_router/go_router.dart';
import '../cubit/auth_cubit.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.pushReplacement('/dashboard');
        }
      },
      builder: (context, state) {
        if (state is AuthUnauthenticated) {
          return const LoginPage();
        }

        if (state is AuthError) {
          // Show error and stay on login page
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
          return const LoginPage();
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
