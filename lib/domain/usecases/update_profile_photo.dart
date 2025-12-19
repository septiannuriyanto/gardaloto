import 'dart:io';
import 'package:gardaloto/domain/repositories/auth_repository.dart';

class UpdateProfilePhoto {
  final AuthRepository repository;

  UpdateProfilePhoto(this.repository);

  Future<String> call(File file, bool isBg) async {
    return await repository.updatePhoto(file, isBg);
  }
}
