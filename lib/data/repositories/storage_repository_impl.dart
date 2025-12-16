import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/data/models/storage_model.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';
import 'package:gardaloto/domain/repositories/storage_repository.dart';

class StorageRepositoryImpl implements StorageRepository {
  static const _boxName = 'storage_box';
  static const _kLastUpdated = 'lastWarehouseUpdated';

  final SupabaseClient _supabase;
  late Box<StorageModel> _box;

  StorageRepositoryImpl(this._supabase);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StorageModelAdapter());
    }
    try {
      _box = await Hive.openBox<StorageModel>(_boxName);
    } catch (e) {
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<StorageModel>(_boxName);
    }
  }

  @override
  Future<String> syncStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdatedStr = prefs.getString(_kLastUpdated);
      final DateTime? lastUpdated =
          lastUpdatedStr != null ? DateTime.tryParse(lastUpdatedStr) : null;

      if (_box.isEmpty) {
        // Initial sync: Fetch all RUNNING
        return await _fetchAllAndSave(prefs);
      } else {
        // Incremental sync
        if (lastUpdated == null) {
          return await _fetchAllAndSave(prefs);
        }
        return await _syncIncremental(prefs, lastUpdated);
      }
    } catch (e) {
      throw Exception('Storage sync failed: $e');
    }
  }

  Future<String> _fetchAllAndSave(SharedPreferences prefs) async {
    final response = await _supabase
        .from('storage')
        .select('warehouse_id, unit_id, status, updated_at')
        .eq('status', 'RUNNING');

    final List<dynamic> data = response as List<dynamic>;
    if (data.isEmpty) return 'No storage data found.';

    await _box.clear();
    final models = data.map((json) => StorageModel.fromJson(json)).toList();
    
    // Save to Hive
    final Map<String, StorageModel> map = {
      for (var m in models) m.warehouseId: m,
    };
    await _box.putAll(map);

    // Update max updated_at
    await _updateLastTimestamp(prefs, models);

    return 'Full storage sync completed. ${models.length} records downloaded.';
  }

  Future<String> _syncIncremental(
    SharedPreferences prefs,
    DateTime lastUpdated,
  ) async {
    // Check count of new records
    final countResponse = await _supabase
        .from('storage')
        .select('warehouse_id') // minimal select for count
        .eq('status', 'RUNNING')
        .gt('updated_at', lastUpdated.toIso8601String())
        .count(CountOption.exact);
    
    final count = countResponse.count;

    if (count == 0) {
      return 'Storage data is up to date.';
    }

    // Fetch new records
    final response = await _supabase
        .from('storage')
        .select('warehouse_id, unit_id, status, updated_at')
        .eq('status', 'RUNNING')
        .gt('updated_at', lastUpdated.toIso8601String());

    final List<dynamic> data = response as List<dynamic>;
    final models = data.map((json) => StorageModel.fromJson(json)).toList();

    // Append/Update Hive
    final Map<String, StorageModel> map = {
      for (var m in models) m.warehouseId: m,
    };
    await _box.putAll(map);

    // Update max updated_at
    await _updateLastTimestamp(prefs, models);

    return 'Synced ${models.length} new/updated storage records.';
  }

  Future<void> _updateLastTimestamp(
    SharedPreferences prefs,
    List<StorageModel> models,
  ) async {
    if (models.isEmpty) return;
    
    // Find max updated_at
    DateTime? maxDate;
    for (var m in models) {
      if (m.updatedAt != null) {
        if (maxDate == null || m.updatedAt!.isAfter(maxDate)) {
          maxDate = m.updatedAt;
        }
      }
    }

    if (maxDate != null) {
      await prefs.setString(_kLastUpdated, maxDate.toIso8601String());
    }
  }

  @override
  Future<List<StorageEntity>> getWarehouses() async {
    return _box.values.map((m) => m.toEntity()).toList();
  }
}
