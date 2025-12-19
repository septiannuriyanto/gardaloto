import 'dart:convert';
import 'dart:io';
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

  @override
  Future<String> updatePhoto(File file, bool isBg) async {
    final user = await getCurrentUser();
    if (user?.nrp == null) throw Exception("User not found or NRP missing");

    final url = await datasource.uploadPhoto(
      nrp: user!.nrp!,
      file: file,
      isBg: isBg,
    );

    // Update Cache
    if (user is UserModel) {
      final newUser = isBg
          ? user.copyWith(bgPhotoUrl: url)
          : user.copyWith(photoUrl: url);
      await _saveUserToPrefs(newUser);
    }
    
    return url;
  }

  @override
  Future<void> deletePhoto(bool isBg) async {
     final user = await getCurrentUser();
    if (user?.nrp == null) throw Exception("User not found or NRP missing");

    await datasource.deletePhoto(nrp: user!.nrp!, isBg: isBg);
    
    // Update Cache (Set to null???)
    // Ah, my copyWith `?? this.val` prevents setting null!
    // I cannot perform a local delete with the current copyWith implementation if I want to set it to null.
    // The current copyWith logic: `photoUrl: photoUrl ?? this.photoUrl` means if I pass null, it keeps `this.photoUrl`.
    // I need to update UserModel to allow clearing fields or just accept that I need a workaround.
    // Workaround: Manually create new UserModel.
    // Or just `_saveUserToPrefs` with modified JSON.
    // Simpler: Just rely on next fetch? No, UI needs immediate update.
    // I SHOULD fix CopyWith or use explicit Manual Copy.
    // Since I can't easily change CopyWith everywhere safely right now without reading all usages,
    // I will construct a new UserModel manually using the fields.
    
    if (user is UserModel) {
       // Manual clone with modification
       final newUser = UserModel(
         id: user.id,
         email: user.email,
         nrp: user.nrp,
         nama: user.nama,
         activeDate: user.activeDate,
         position: user.position,
         sidCode: user.sidCode,
         positionDescription: user.positionDescription,
         photoUrl: isBg ? user.photoUrl : null, // Clear if not bg
         bgPhotoUrl: isBg ? null : user.bgPhotoUrl, // Clear if bg
       );
       await _saveUserToPrefs(newUser);
    }
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

  @override
  Future<void> resetPassword(String nrp) async {
    await datasource.resetPassword(nrp);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await datasource.updatePassword(newPassword);
  }
}
