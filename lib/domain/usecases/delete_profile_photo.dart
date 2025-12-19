import 'package:gardaloto/domain/repositories/auth_repository.dart';

class DeleteProfilePhoto {
  final AuthRepository repository;

  DeleteProfilePhoto(this.repository);

  Future<void> call(bool isBg) async {
    return await repository.deletePhoto(isBg);
  }
}
