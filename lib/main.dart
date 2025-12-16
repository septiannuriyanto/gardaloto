import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/secret.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================
  // INIT SUPABASE
  // =========================
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // =========================
  // INIT SERVICE LOCATOR
  // =========================
  // Ensure all services are registered before running the app.
  await initServiceLocator();

  runApp(const MyApp());
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
