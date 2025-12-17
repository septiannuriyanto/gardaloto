import 'package:gardaloto/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> login(String nrp, String password);
  Future<void> logout();
  Future<UserEntity?> getCurrentUser();
}
