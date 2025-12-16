import 'package:gardaloto/domain/entities/manpower_entity.dart';

abstract class ManpowerRepository {
  /// Syncs manpower data from Supabase to local storage.
  /// Returns a message describing the result (e.g., "Synced 5 new records").
  Future<String> syncManpower();

  /// Returns all fuelmen (position = 5).
  Future<List<ManpowerEntity>> getFuelmen();

  /// Returns all operators (position = 4).
  Future<List<ManpowerEntity>> getOperators();
}
