import 'package:gardaloto/domain/repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository repository;

  RegisterUser(this.repository);

  Future<void> call({
    required String nrp,
    required String name,
    required String email,
    required String password,
    String? sidCode,
  }) async {
    return repository.register(
      nrp: nrp,
      name: name,
      email: email,
      password: password,
      sidCode: sidCode,
    );
  }
}
