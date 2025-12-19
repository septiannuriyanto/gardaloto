import 'package:gardaloto/domain/repositories/auth_repository.dart';

class UpdatePassword {
  final AuthRepository repository;

  UpdatePassword(this.repository);

  Future<void> call(String newPassword) async {
    return repository.updatePassword(newPassword);
  }
}
