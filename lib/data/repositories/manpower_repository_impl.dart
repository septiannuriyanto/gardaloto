import 'dart:convert';
import 'package:gardaloto/data/datasources/manpower_datasource.dart';
import 'package:gardaloto/data/models/user_model.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/entities/incumbent_entity.dart';
import 'package:gardaloto/domain/repositories/manpower_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gardaloto/data/models/incumbent_model.dart';

class ManpowerRepositoryImpl implements ManpowerRepository {
  final ManpowerDatasource datasource;
  late SharedPreferences _prefs;

  ManpowerRepositoryImpl(this.datasource);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    // For admin, fetch fresh from DB
    return await datasource.fetchAllUsers();
  }

  @override
  Future<void> toggleUserStatus(String nrp, bool isActive) async {
    await datasource.updateUserStatus(nrp, isActive);
    // Optionally update local cache if we want to reflect changes immediately
    // blocked by sync logic complexity, so sticking to remote source check for admin.
  }

  @override
  Future<void> deleteUser(String nrp) async {
    await datasource.deleteUser(nrp);
  }

  // === RESTORED SYNC LOGIC ===

  @override
  Future<void> syncManpower() async {
    try {
      final users = await datasource.fetchAllUsers();
      final List<Map<String, dynamic>> jsonList = users.map((u) => u.toJson()).toList();
      await _prefs.setString('manpower_cache', jsonEncode(jsonList));
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  @override
  Future<List<ManpowerEntity>> getFuelmen() async {
    return _getManpowerByPosition(5); 
  }

  @override
  Future<List<ManpowerEntity>> getOperators() async {
      return _getManpowerByPosition(4);
  }
  
  @override
  Future<void> unregisterUser(String nrp) async {
    await datasource.unregisterUser(nrp);
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    if (user is UserModel) {
       await datasource.updateUser(user);
    } else {
       // Convert UserEntity to UserModel if needed, or simple cast/copy
       // Since UserEntity is just the base, we should probably construct a UserModel from it
       // But assuming we pass UserModel from UI logic essentially.
       await datasource.updateUser(
         UserModel(
           id: user.id,
           email: user.email,
           nrp: user.nrp,
           nama: user.nama,
           active: user.active,
           position: user.position,
           sidCode: user.sidCode,
           section: user.section,
           // ... others
         )
       );
    }
  }

  @override
  Future<List<IncumbentEntity>> getIncumbents() async {
    final list = await datasource.fetchIncumbents();
    return list.map((json) => IncumbentModel.fromJson(json)).toList();
  }

  @override
  Future<void> addManpower(String nrp) async {
    await datasource.insertManpower(nrp);
  }

  Future<List<ManpowerEntity>> _getManpowerByPosition(int pos) async {
    final jsonStr = _prefs.getString('manpower_cache');
    if (jsonStr == null) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((item) {
             return ManpowerEntity(
               nrp: item['nrp'],
               nama: item['nama'],
               sidCode: item['sidCode'], // Note: UserModel toJson uses camelCase keys 'sidCode'
               position: item['position'],
               email: item['email'],
             );
          })
          .where((e) => e.position == pos)
          .toList();
    } catch (e) {
      print('Error parsing manpower cache: $e');
      return [];
    }
  }
}
