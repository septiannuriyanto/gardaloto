import 'package:gardaloto/presentation/pages/auth_gate.dart';
import 'package:gardaloto/presentation/pages/dashboard_page.dart';
import 'package:gardaloto/presentation/pages/fit_to_work_page.dart';
import 'package:gardaloto/presentation/pages/loto_page.dart';
import 'package:gardaloto/presentation/pages/loto_review_page.dart';
import 'package:gardaloto/presentation/pages/loto_sessions_page.dart';
import 'package:gardaloto/presentation/widget/capture_form_page.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';

import 'package:gardaloto/presentation/pages/ready_to_work_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(path: '/', name: 'auth_gate', builder: (_, __) => const AuthGate()),

    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: '/loto',
      name: 'loto',
      builder: (_, __) => const LotoSessionsPage(),
      routes: [
        GoRoute(
          path: 'entry',
          name: 'loto_entry',
          builder: (context, state) {
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => sl<ManpowerCubit>()),
                BlocProvider(create: (_) => sl<StorageCubit>()),
              ],
              child: const LotoPage(),
            );
          },
        ),
        GoRoute(
          path: 'capture',
          name: 'capture',
          builder: (_, __) => const CaptureFormPage(),
        ),
        GoRoute(
          path: 'review',
          name: 'loto_review',
          builder: (context, state) {
            final session = state.extra as LotoSession;
            return LotoReviewPage(session: session);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/fit',
      name: 'fit',
      builder: (_, __) => const FitToWorkPage(),
    ),
    GoRoute(
      path: '/ready',
      name: 'ready',
      builder: (_, __) => const ReadyToWorkPage(),
    ),
  ],
);
