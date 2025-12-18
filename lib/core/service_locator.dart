import 'package:gardaloto/data/datasources/supabase_auth_datasource.dart';
import 'package:gardaloto/data/repositories/auth_repository_impl.dart';
import 'package:gardaloto/domain/repositories/auth_repository.dart';
import 'package:gardaloto/domain/usecases/get_current_user.dart';
import 'package:gardaloto/domain/usecases/login_user.dart';
import 'package:gardaloto/domain/usecases/logout_user.dart';
import 'package:gardaloto/domain/usecases/send_loto_report.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/data/repositories/loto_repository_impl.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/data/repositories/loto_master_repository.dart';
import 'package:gardaloto/domain/repositories/manpower_repository.dart';
import 'package:gardaloto/data/repositories/manpower_repository_impl.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/domain/repositories/storage_repository.dart';
import 'package:gardaloto/data/repositories/storage_repository_impl.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_sessions_cubit.dart';
import 'package:gardaloto/domain/repositories/unit_repository.dart';
import 'package:gardaloto/data/repositories/unit_repository_impl.dart';
import 'package:gardaloto/presentation/cubit/unit_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // =========================
  // EXTERNAL
  // =========================
  final supabaseClient = Supabase.instance.client;

  sl.registerLazySingleton<SupabaseClient>(() => supabaseClient);

  // =========================
  // AUTH DATASOURCE
  // =========================
  sl.registerLazySingleton<SupabaseAuthDatasource>(
    () => SupabaseAuthDatasource(sl<SupabaseClient>()),
  );

  // =========================
  // AUTH REPOSITORY
  // =========================
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<SupabaseAuthDatasource>()),
  );

  // =========================
  // USE CASES
  // =========================
  sl.registerLazySingleton(() => LoginUser(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUser(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetCurrentUser(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SendLotoReport(sl<LotoRepository>()));

  // =========================
  // CUBIT
  // =========================
  // LOTO
  final _lotoRepo = LotoRepositoryImpl(sl<SupabaseClient>());
  await _lotoRepo.init();
  sl.registerLazySingleton<LotoRepository>(() => _lotoRepo);
  // LOTO MASTER (shared preferences)
  final _masterRepo = await LotoMasterRepository.create();
  sl.registerLazySingleton(() => _masterRepo);
  sl.registerLazySingleton(() => LotoCubit(sl<LotoRepository>()));

  // MANPOWER
  final _manpowerRepo = ManpowerRepositoryImpl(sl<SupabaseClient>());
  await _manpowerRepo.init();
  sl.registerLazySingleton<ManpowerRepository>(() => _manpowerRepo);
  sl.registerFactory(() => ManpowerCubit(sl<ManpowerRepository>()));

  // STORAGE
  final _storageRepo = StorageRepositoryImpl(sl<SupabaseClient>());
  await _storageRepo.init();
  sl.registerLazySingleton<StorageRepository>(() => _storageRepo);
  sl.registerFactory(() => StorageCubit(sl<StorageRepository>()));
  sl.registerFactory(() => LotoSessionsCubit(sl<LotoRepository>()));

  // UNIT RECOMMENDATIONS
  sl.registerLazySingleton<UnitRepository>(
    () => UnitRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory(() => UnitCubit(sl<UnitRepository>()));

  sl.registerFactory(
    () => AuthCubit(
      loginUser: sl<LoginUser>(),
      logoutUser: sl<LogoutUser>(),
      getCurrentUser: sl<GetCurrentUser>(),
    ),
  );
}
