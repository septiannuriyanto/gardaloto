import 'package:gardaloto/data/models/user_model.dart';
import 'package:supabase/supabase.dart';

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
      final manpowerData = await client
          .from('manpower')
          .select()
          .eq('nrp', nrp)
          .maybeSingle();

      if (manpowerData == null) {
        throw Exception('NRP not found');
      }

      final email = manpowerData['email'] as String?;
      if (email == null || email.isEmpty) {
        throw Exception('Email not registered for this NRP');
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

      // 3. Construct UserModel from Manpower Data
      return UserModel.fromManpower(manpowerData, res.user!.id);
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
}
