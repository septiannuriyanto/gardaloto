import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/secret.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/version_cubit.dart';
import 'package:gardaloto/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================
  // INIT SUPABASE & SERVICE LOCATOR
  // =========================
  try {
    // Initialize Supabase first
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

    // Ensure all services are registered before running the app.
    await initServiceLocator();
  } catch (e, stack) {
    debugPrint('❌ Fatal Error during initialization: $e');
    debugPrint(stack.toString());
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Initialization Failed:\n$e\n\n$stack',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runZonedGuarded(
    () {
      runApp(const MyApp());
    },
    (error, stack) {
      if (error is AuthException) {
        // Catch Supabase Auth exceptions (like expired links) to prevent crash
        debugPrint('Caught AuthException in zone: ${error.message}');

        if (error.statusCode == 'otp_expired' ||
            error.message.contains('expired')) {
          // Show error to user via SnackBar if context is available
          final context = router.routerDelegate.navigatorKey.currentContext;
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'The password reset link has expired. Please request a new one.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }
      // For other errors, rethrow or log
      debugPrint('Uncaught error: $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => sl<AuthCubit>()),
        BlocProvider<LotoCubit>(
          create: (_) => sl<LotoCubit>()..loadLocalRecords(),
        ),
        BlocProvider<VersionCubit>(
          create: (_) => sl<VersionCubit>()..checkVersion(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'GARDA LOTO',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerDelegate: router.routerDelegate,
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
      ),
    );
  }
}
