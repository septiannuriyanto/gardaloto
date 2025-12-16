import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository repo;
  GetCurrentUser(this.repo);

  Future<UserEntity?> call() => repo.getCurrentUser();
}
