import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:supabase/supabase.dart';

class UserModel extends UserEntity {
  UserModel({required super.id, required super.email});

  factory UserModel.fromSupabase(User user) {
    return UserModel(id: user.id, email: user.email ?? '');
  }
}
