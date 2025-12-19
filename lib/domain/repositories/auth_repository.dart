import 'dart:io';
import 'package:gardaloto/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> login(String nrp, String password);
  Future<void> logout();
  Future<UserEntity?> getCurrentUser();
  Future<String> updatePhoto(File file, bool isBg);
  Future<void> deletePhoto(bool isBg);
  Future<void> resetPassword(String nrp);
  Future<void> updatePassword(String newPassword);
}
