import 'package:gardaloto/domain/entities/user_entity.dart';

sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthNeedsRegistration extends AuthState {
  final String nrp;
  AuthNeedsRegistration(this.nrp);
}

class AuthRegistered extends AuthState {}

class AuthPasswordResetEmailSent extends AuthState {}

class AuthPasswordUpdated extends AuthState {}
