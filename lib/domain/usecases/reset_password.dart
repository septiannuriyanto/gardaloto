import 'package:gardaloto/domain/repositories/auth_repository.dart';

class ResetPassword {
  final AuthRepository repository;

  ResetPassword(this.repository);

  Future<void> call(String nrp) async {
    return repository.resetPassword(nrp);
  }
}
