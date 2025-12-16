import 'package:gardaloto/domain/entities/storage_entity.dart';

abstract class StorageRepository {
  /// Syncs storage data from Supabase to local storage.
  /// Returns a message describing the result.
  Future<String> syncStorage();

  /// Returns all warehouses (storage records).
  Future<List<StorageEntity>> getWarehouses();
}
