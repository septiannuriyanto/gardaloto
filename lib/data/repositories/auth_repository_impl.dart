import 'dart:convert';
import 'package:gardaloto/data/datasources/supabase_auth_datasource.dart';
import 'package:gardaloto/data/models/user_model.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource datasource;

  AuthRepositoryImpl(this.datasource);

  @override
  Future<UserEntity?> login(String nrp, String password) async {
    final user = await datasource.signInWithNrp(nrp, password);
    if (user != null) {
      await _saveUserToPrefs(user);
    }
    return user;
  }

  @override
  Future<void> logout() async {
    await datasource.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    // 1. Check if we have an active session from Supabase
    final sbUser = await datasource.currentUser();
    if (sbUser == null) {
       // Session expired or invalid
       final prefs = await SharedPreferences.getInstance();
       await prefs.remove('user_data');
       return null;
    }

    // 2. Try to load rich user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(userJson);
        return UserModel.fromJson(map);
      } catch (e) {
        print('Error parsing user data from prefs: $e');
      }
    }

    // 3. Fallback: return the basic user from Supabase (only id/email)
    // Ideally we might want to re-fetch from Manpower here if missing locally
    return sbUser;
  }

  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(user.toJson());
      await prefs.setString('user_data', jsonStr);
    } catch (e) {
      print('Error saving user to prefs: $e');
    }
  }
}
