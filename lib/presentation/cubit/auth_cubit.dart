import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/usecases/get_current_user.dart';
import 'package:gardaloto/domain/usecases/login_user.dart';
import 'package:gardaloto/domain/usecases/logout_user.dart';
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

  AuthCubit({
    required this.loginUser,
    required this.logoutUser,
    required this.getCurrentUser,
    required this.updateProfilePhotoUseCase,
    required this.deleteProfilePhotoUseCase,
    required this.resetPasswordUseCase,
    required this.updatePasswordUseCase,
  }) : super(AuthInitial()) {
    _loadCurrentUser();
    // Listen for Password Recovery event
    // We can't easily access Supabase instance here directly without injecting it or using a stream.
    // For now, let's assume the router or a top-level listener handles the DEEP LINK redirection to the UpdatePasswordPage.
    // However, Supabase Auth state change 'passwordRecovery' is emitted when the user clicks the link.
    // Let's defer that logic to the Router or a separate listener if needed, OR handling it here if we want to emit a state.
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

  Future<void> sendPasswordResetEmail(String nrp) async {
    emit(AuthLoading());
    try {
      await resetPasswordUseCase(nrp);
      emit(AuthPasswordResetEmailSent());
      // Revert to Unauthenticated after showing success logic (handled in UI listener)
      // Allow a brief moment for UI listeners to react if needed,
      // but simpler to just revert immediately or after next event loop.
      // Since ForgotPasswordPage pops on this state, this transition helps AuthGate render Login page cleanly.
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
      // We should go back to Unauthenticated state eventually so user can retry or login
      // But let the UI handle the error state first
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
