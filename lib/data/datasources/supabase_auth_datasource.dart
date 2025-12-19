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

  String _sanitizeNrp(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Future<UserModel?> signInWithNrp(String nrp, String password) async {
    try {
      final sanitizedNrp = _sanitizeNrp(nrp);
      // 1. Lookup Email by NRP
      // Fetch Basic Manpower Data first
      final manpowerData = await client
          .from('manpower')
          .select() // Select all columns
          .eq('nrp', sanitizedNrp)
          .maybeSingle();

      if (manpowerData == null) {
        throw Exception('NRP not found');
      }

      // Check if account is active
      final isActive = manpowerData['active'] as bool? ?? true; // Default to true if null, or user preference? 
      // User said: "If the active column is false, then it shows snackbar"
      // Safest is to handle explicit false.
      if (isActive == false) {
        throw Exception('Contact your supervisor to activate your account');
      }

      final email = manpowerData['email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('Anda belum mendaftarkan email, hubungi pengawas atau admin untuk mendaftarkan email pada akun anda');
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

  Future<void> register({
    required String nrp,
    required String name,
    required String email,
    required String password,
    String? sidCode,
  }) async {
    try {
      final sanitizedNrp = _sanitizeNrp(nrp);
      final sanitizedName = name.toUpperCase();

      // 1. Check if NRP exists in manpower
      // ... logic skipped for brevity if identical, but full replacement is safer here ...
      // Actually previous code checked creation. Wait, previous log shows "Check if NRP exists" 
      // User request implies registration into EXISTING manpower or NEW? 
      // "insert into manpower" was in Step 831 replacement code logic (which assumed new record). 
      // BUT current file content (Step 853) shows logic that UPDATES existing manpower record:
      // "await client.from('manpower').update({...}).eq('nrp', sanitizedNrp);"
      
      // If the user flow is "Register for account" where NRP exists, we UPDATE.
      // If the user flow is "Create new manpower", we INSERT.
      // Based on Step 853 code, it does an UPDATE.
      // So I should stick to UPDATE logic but add sid_code and position: null.
      
      // 1. Check if NRP exists in manpower
      final manpowerData = await client
          .from('manpower')
          .select()
          .eq('nrp', sanitizedNrp)
          .maybeSingle();

      if (manpowerData == null) {
        // If NRP not found, maybe we should INSERT? 
        // But the current code throws "NRP not found in database. Contact Admin."
        // This implies users must already be in manpower list (pre-populated by admin).
        // I will stick to this logic unless instructed otherwise.
         throw Exception('NRP not found in database. Contact Admin.');
      }

      // 2. Sign Up with Supabase Auth
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {'nrp': sanitizedNrp, 'full_name': sanitizedName},
      );

      if (res.user == null) {
        throw Exception('Registration failed');
      }

      // 3. Update manpower table
      await client
          .from('manpower')
          .update({
            'email': email,
            'nama': sanitizedName,
            'active': false,
            'sid_code': sidCode,
            'position': null, // Explicitly null as requested
          })
          .eq('nrp', sanitizedNrp);

    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String nrp) async {
    try {
      final sanitizedNrp = _sanitizeNrp(nrp);
      // 1. Lookup Email by NRP
      // Select email and user_id to distinguish account existence
      // If 'user_id' doesn't exist in table, this might error if we SELECT it explicitly.
      // But query 'select()' fetches all.
      final manpowerData = await client
          .from('manpower')
          .select() 
          .eq('nrp', sanitizedNrp)
          .maybeSingle();

      if (manpowerData == null) {
        throw Exception('NRP not found');
      }

      final email = manpowerData['email'] as String?;
      final userId = manpowerData['user_id']; // Trying to detect if auth account exists

      if (email == null || email.isEmpty) {
        if (userId == null) {
             throw Exception('NEEDS_REGISTER'); 
        } else {
             throw Exception('Email belum tersimpan dalam akun, hubungi pengawas untuk update alamat email');
        }
      }
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
