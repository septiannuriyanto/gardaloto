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

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<UserModel?> currentUser() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabase(user);
  }
}
