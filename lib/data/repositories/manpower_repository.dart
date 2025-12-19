import 'package:gardaloto/data/datasources/manpower_datasource.dart';
import 'package:gardaloto/data/models/user_model.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';

abstract class ManpowerRepository {
  Future<List<UserEntity>> getAllUsers();
  Future<void> toggleUserStatus(String nrp, bool isActive);
  Future<void> deleteUser(String nrp);
}

class ManpowerRepositoryImpl implements ManpowerRepository {
  final ManpowerDatasource datasource;

  ManpowerRepositoryImpl(this.datasource);

  @override
  Future<List<UserEntity>> getAllUsers() async {
    return await datasource.fetchAllUsers();
  }

  @override
  Future<void> toggleUserStatus(String nrp, bool isActive) async {
    await datasource.updateUserStatus(nrp, isActive);
  }
  
  @override
  Future<void> deleteUser(String nrp) async {
    await datasource.deleteUser(nrp);
  }
}
