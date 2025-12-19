import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/data/models/user_model.dart';

class ManpowerDatasource {
  final SupabaseClient client;

  ManpowerDatasource(this.client);

  Future<List<UserModel>> fetchAllUsers() async {
    try {
      final response = await client
          .from('manpower')
          .select('*, incumbent(*)')
          .eq('registered', true) // Only registered users
          .order('active', ascending: true)
          .order('nama', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.map((json) {
         final authId = json['user_id'] as String? ?? '';
         return UserModel.fromManpower(json, authId);
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> fetchUnregisteredUsers() async {
     // Optional: if we need to see unregistered users separately? 
     // For now just implementing what's asked.
     return [];
  }

  Future<void> updateUserStatus(String nrp, bool isActive) async {
    try {
      await client
          .from('manpower')
          .update({'active': isActive})
          .eq('nrp', nrp);
    } catch (e) {
      print('Error updating user status: $e');
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await client.from('manpower').update({
        'nama': user.nama,
        'email': user.email,
        'sid_code': user.sidCode,
        'position': user.position,
        'section': user.section,
        'active': user.active,
        // updated_at is auto-handled by DB trigger usually, but we can set it if needed.
        // If DB has "default now()", it updates on row change? Depends on trigger.
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('nrp', user.nrp!);
    } catch (e) {
       print('Error updating user : $e');
       rethrow;
    }
  }

  Future<void> unregisterUser(String nrp) async {
    try {
       await client.from('manpower').update({'registered': false, 'active': false}).eq('nrp', nrp);
    } catch (e) {
       print('Error unregistering user: $e');
       rethrow;
    }
  }
  
  Future<void> deleteUser(String nrp) async {
      await client.from('manpower').delete().eq('nrp', nrp);
  }

  Future<void> insertManpower(String nrp) async {
    try {
      final sanitized = nrp.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (sanitized.isEmpty) throw Exception("Invalid NRP");

      // Check if exists? Unique constraint will handle it, but nicer error might be good.
      // But for simplicity let DB error bubble or handle it.
      
      await client.from('manpower').insert({
        'nrp': sanitized,
        'active': false, 
                        // Usually admin adds NRP so user can register.
                        // "send the sanitized and uppercased nrp to table manpower"
        'registered': false,
        'position': null,
      });
    } catch (e) {
      print('Error inserting manpower: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchIncumbents() async {
    try {
      final response = await client
          .from('incumbent')
          .select('id, incumbent')
          .order('id', ascending: true);
      return (response as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching incumbents: $e');
      rethrow;
    }
  }
}
