import 'dart:io';
import 'package:gardaloto/data/models/user_model.dart';
import 'package:supabase/supabase.dart';
import 'package:path/path.dart' as path;

class SupabaseAuthDatasource {
  final SupabaseClient client;

  SupabaseAuthDatasource(this.client);

  Future<UserModel?> signIn(String email, String password) async {
    try {
      final res = await client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Auth request timed out');
            },
          );

      if (res.user == null) return null;
      return UserModel.fromSupabase(res.user!);
    } catch (e, st) {
      // Log the issue for easier debugging, and rethrow so upper layers
      // can decide how to handle it (e.g., show error in UI).
      print('SupabaseAuthDatasource.signIn error: $e\n$st');
      rethrow;
    }
  }

  Future<UserModel?> signInWithNrp(String nrp, String password) async {
    try {
      // 1. Lookup Email by NRP
      // Fetch Basic Manpower Data first
      final manpowerData = await client
          .from('manpower')
          .select() // Select all columns
          .eq('nrp', nrp)
          .maybeSingle();

      if (manpowerData == null) {
        throw Exception('NRP not found');
      }

      final email = manpowerData['email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('Email not registered for this NRP');
      }

      // 1b. Fetch Position Description Separately (Safer than JOIN)
      String? positionDesc;
      final positionId = manpowerData['position'];
      if (positionId != null) {
        try {
          final incumbentData = await client
              .from('incumbent')
              .select('incumbent')
              .eq('id', positionId)
              .maybeSingle();
          
          if (incumbentData != null) {
            positionDesc = incumbentData['incumbent'] as String?;
          }
        } catch (e) {
          print('Error fetching position description: $e');
        }
      }

      // 2. Sign In with Email & Password
      final res = await client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Auth request timed out');
            },
          );

      if (res.user == null) return null;

      // 3. Construct UserModel
      // Inject the fetched description into a structure that UserModel understands
      // Or better: Update UserModel.fromManpower to accept it.
      // For now, let's mimic the structure UserModel expects IF we didn't change UserModel.
      // But I can also just manually add it to the map if it's mutable.
      final Map<String, dynamic> combinedData = Map.from(manpowerData);
      if (positionDesc != null) {
        combinedData['incumbent'] = {'incumbent': positionDesc};
      }

      return UserModel.fromManpower(combinedData, res.user!.id);
    } catch (e, st) {
      print('SupabaseAuthDatasource.signInWithNrp error: $e\n$st');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<UserModel?> currentUser() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabase(user);
  }

  Future<String> uploadPhoto({
    required String nrp,
    required File file,
    required bool isBg,
  }) async {
    try {
      final ext = path.extension(file.path);
      final fileName = isBg ? '$nrp-bg$ext' : '$nrp$ext';
      final storagePath = 'profile/$fileName';

      // 1. Upload to Storage (Upsert)
      await client.storage.from('images').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Get Public URL
      final publicUrl = client.storage.from('images').getPublicUrl(storagePath);
      // Hack: Add timestamp query param to force refresh if needed, but standard URL is cleaner.
      // CachedNetworkImage handles caching. If we overwrite, we might need to evict cache in UI.
      // For now just return the URL.

      // 3. Update Manpower Table
      final column = isBg ? 'bg_photo_url' : 'photo_url';
      await client
          .from('manpower')
          .update({column: publicUrl}).eq('nrp', nrp);

      return publicUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      rethrow;
    }
  }

  Future<void> deletePhoto({
    required String nrp,
    required bool isBg,
  }) async {
    try {
      // 1. Update Manpower Table (Set to null)
      final column = isBg ? 'bg_photo_url' : 'photo_url';
      await client
          .from('manpower')
          .update({column: null}).eq('nrp', nrp);

      // 2. Try delete from storage (Optional/Best Effort)
      // Skipped for complexity/safety as per comment above.
    } catch (e) {
      print('Error deleting photo: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String nrp) async {
    try {
      // 1. Lookup Email by NRP
      final manpowerData = await client
          .from('manpower')
          .select('email')
          .eq('nrp', nrp)
          .maybeSingle();

      if (manpowerData == null) {
        throw Exception('NRP not found');
      }

      final email = manpowerData['email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('Email not registered for this NRP');
      }

      // 2. Send Reset Password Email (Magic Link)
      // Redirect to deep link
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'gardaloto://reset-callback',
      );
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      print('Error updating password: $e');
      rethrow;
    }
  }
}
