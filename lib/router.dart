import 'package:gardaloto/presentation/pages/auth_gate.dart';
import 'package:gardaloto/presentation/pages/dashboard_page.dart';
import 'package:gardaloto/presentation/pages/fit_to_work_page.dart';
import 'package:gardaloto/presentation/pages/loto_page.dart';
import 'package:gardaloto/presentation/pages/loto_review_page.dart';
import 'package:gardaloto/presentation/pages/loto_sessions_page.dart';
import 'package:gardaloto/presentation/widget/capture_form_page.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';

import 'package:gardaloto/presentation/pages/ready_to_work_page.dart';
import 'package:gardaloto/presentation/pages/forgot_password_page.dart';
import 'package:gardaloto/presentation/pages/update_password_page.dart';
import 'package:gardaloto/presentation/pages/register_page.dart';
import 'package:gardaloto/presentation/pages/reset_callback_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/pages/account_page.dart';
import 'package:gardaloto/presentation/pages/control_panel_page.dart';
import 'package:gardaloto/presentation/pages/user_management_page.dart';
import 'package:gardaloto/presentation/pages/modify_user_page.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/presentation/pages/about_page.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/reset-callback',
      name: 'reset_callback',
      builder: (_, state) {
        final error = state.uri.queryParameters['error'];
        final errorDescription = state.uri.queryParameters['error_description'];
        return ResetCallbackPage(
          error: error,
          errorDescription: errorDescription,
        );
      },
    ),

    GoRoute(path: '/', name: 'auth_gate', builder: (_, __) => const AuthGate()),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot_password',
      builder: (_, __) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (_, state) {
        final nrp = state.extra as String?;
        return RegisterPage(initialNrp: nrp);
      },
    ),

    GoRoute(
      path: '/update-password',
      name: 'update_password',
      builder: (_, __) => const UpdatePasswordPage(),
    ),

    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: '/account',
      name: 'account',
      builder: (_, __) => const AccountPage(),
    ),
    GoRoute(
      path: '/loto',
      name: 'loto',
      builder: (context, state) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<ManpowerCubit>()),
            BlocProvider(create: (_) => sl<StorageCubit>()),
          ],
          child: const LotoPage(),
        );
      },
      routes: [
        GoRoute(
          path: 'sessions',
          name: 'loto_sessions',
          builder: (_, __) => const LotoSessionsPage(),
        ),
        GoRoute(
          path: 'capture',
          name: 'capture',
          builder: (context, state) {
            // Check if a specific LotoCubit was passed (e.g. from Review Page)
            final extra = state.extra as Map<String, dynamic>?;
            final injectedCubit = extra?['cubit'] as LotoCubit?;

            if (injectedCubit != null) {
              return BlocProvider.value(
                value: injectedCubit,
                child: const CaptureFormPage(),
              );
            }
            return const CaptureFormPage();
          },
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
    GoRoute(
      path: '/control-panel',
      name: 'control_panel',
      builder: (_, __) => const ControlPanelPage(),
    ),
    GoRoute(
      path: '/user-management',
      name: 'user_management',
      builder: (context, state) => const UserManagementPage(),
      routes: [
        GoRoute(
          path: 'modify-user',
          name: 'modify_user',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            final user = extra['user'] as UserEntity;
            final cubit = extra['cubit'] as ManpowerCubit;
            return BlocProvider.value(
              value: cubit,
              child: ModifyUserPage(user: user),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (_, __) => const AboutPage(),
    ),
  ],
);
