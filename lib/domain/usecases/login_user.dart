import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repo;
  LoginUser(this.repo);

  Future<UserEntity?> call(String email, String password) {
    return repo.login(email, password);
  }
}
