import 'package:gardaloto/domain/entities/incumbent_entity.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';

abstract class ManpowerRepository {
  /// Syncs manpower data from Supabase to local storage.
  Future<void> syncManpower();

  /// Returns all fuelmen (position = 8).
  Future<List<ManpowerEntity>> getFuelmen();

  /// Returns all operators (position = 4).
  Future<List<ManpowerEntity>> getOperators();

  /// Returns all users (for Admin Control Panel).
  Future<List<UserEntity>> getAllUsers();

  /// Toggles user active status.
  Future<void> toggleUserStatus(String nrp, bool isActive);

  /// Unregisters a user (registered = false).
  Future<void> unregisterUser(String nrp);

  /// Updates user details.
  Future<void> updateUser(UserEntity user);

  /// SQL Delete or Soft Delete a user.
  Future<void> deleteUser(String nrp);

  /// Fetch list of positions.
  Future<List<IncumbentEntity>> getIncumbents();

  /// Add new NRP (Manpower).
  Future<void> addManpower(String nrp);
}
