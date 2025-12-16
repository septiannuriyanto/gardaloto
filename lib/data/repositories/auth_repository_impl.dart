import 'package:gardaloto/data/datasources/supabase_auth_datasource.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource datasource;

  AuthRepositoryImpl(this.datasource);

  @override
  Future<UserEntity?> login(String email, String password) {
    return datasource.signIn(email, password);
  }

  @override
  Future<void> logout() {
    return datasource.signOut();
  }

  @override
  Future<UserEntity?> getCurrentUser() {
    return datasource.currentUser();
  }
}
