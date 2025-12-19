import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/usecases/get_current_user.dart';
import 'package:gardaloto/domain/usecases/login_user.dart';
import 'package:gardaloto/domain/usecases/logout_user.dart';
import 'package:gardaloto/domain/usecases/register_user.dart';
import 'package:gardaloto/domain/usecases/reset_password.dart';
import 'package:gardaloto/domain/usecases/update_password.dart';
import 'package:gardaloto/domain/usecases/update_profile_photo.dart';
import 'package:gardaloto/domain/usecases/delete_profile_photo.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUser loginUser;
  final LogoutUser logoutUser;
  final GetCurrentUser getCurrentUser;
  final UpdateProfilePhoto updateProfilePhotoUseCase;
  final DeleteProfilePhoto deleteProfilePhotoUseCase;
  final ResetPassword resetPasswordUseCase;
  final UpdatePassword updatePasswordUseCase;

  final RegisterUser registerUserUseCase;

  AuthCubit({
    required this.loginUser,
    required this.logoutUser,
    required this.getCurrentUser,
    required this.updateProfilePhotoUseCase,
    required this.deleteProfilePhotoUseCase,
    required this.resetPasswordUseCase,
    required this.updatePasswordUseCase,
    required this.registerUserUseCase,
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

  Future<void> login(String nrp, String password) async {
    emit(AuthLoading());
    try {
      final user = await loginUser(nrp, password).timeout(
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

  Future<void> updatePhoto(File file, bool isBg) async {
    emit(AuthLoading());
    try {
      await updateProfilePhotoUseCase(file, isBg);
      await _loadCurrentUser();
    } catch (e) {
      emit(AuthError(e.toString()));
      // Silent reload to restore previous valid state user object if possible
      // or at least clear loading state
      _loadCurrentUser();
    }
  }

  Future<void> deletePhoto(bool isBg) async {
    emit(AuthLoading());
    try {
      await deleteProfilePhotoUseCase(isBg);
      await _loadCurrentUser();
    } catch (e) {
      emit(AuthError(e.toString()));
      _loadCurrentUser();
    }
  }

  Future<void> register({
    required String nrp,
    required String name,
    required String email,
    required String password,
    String? sidCode,
  }) async {
    emit(AuthLoading());
    try {
      await registerUserUseCase(
        nrp: nrp,
        name: name,
        email: email,
        password: password,
        sidCode: sidCode,
      );
      // Logout explicitly to prevent auto-login since account is inactive by default
      await logoutUser();
      emit(AuthRegistered());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> sendPasswordResetEmail(String nrp) async {
    emit(AuthLoading());
    try {
      await resetPasswordUseCase(nrp);
      emit(AuthPasswordResetEmailSent());
      emit(AuthUnauthenticated());
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      
      if (message == 'NEEDS_REGISTER') {
        emit(AuthNeedsRegistration(nrp));
      } else {
        emit(AuthError(message));
      }
    }
  }

  Future<void> confirmPasswordReset(String newPassword) async {
    emit(AuthLoading());
    try {
      await updatePasswordUseCase(newPassword);
      await logoutUser(); // Force logout so user must login again
      emit(AuthPasswordUpdated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
