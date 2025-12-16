import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/usecases/get_current_user.dart';
import 'package:gardaloto/domain/usecases/login_user.dart';
import 'package:gardaloto/domain/usecases/logout_user.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUser loginUser;
  final LogoutUser logoutUser;
  final GetCurrentUser getCurrentUser;

  AuthCubit({
    required this.loginUser,
    required this.logoutUser,
    required this.getCurrentUser,
  }) : super(AuthInitial()) {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    emit(AuthLoading());
    try {
      final user = await getCurrentUser().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Loading current user timed out');
        },
      );
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await loginUser(email, password).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Login request timed out');
        },
      );
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthError("Login gagal"));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    try {
      await logoutUser();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
