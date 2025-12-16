import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/data/models/manpower_model.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/repositories/manpower_repository.dart';

class ManpowerRepositoryImpl implements ManpowerRepository {
  static const _boxName = 'manpower_box';
  static const _kLastUpdated = 'lastManpowerUpdated';

  final SupabaseClient _supabase;
  late Box<ManpowerModel> _box;

  ManpowerRepositoryImpl(this._supabase);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ManpowerModelAdapter());
    }
    try {
      _box = await Hive.openBox<ManpowerModel>(_boxName);
    } catch (e) {
      // If box is corrupted, delete and recreate
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<ManpowerModel>(_boxName);
    }
  }

  @override
  Future<String> syncManpower() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdatedStr = prefs.getString(_kLastUpdated);
      final DateTime? lastUpdated =
          lastUpdatedStr != null ? DateTime.tryParse(lastUpdatedStr) : null;

      if (_box.isEmpty) {
        // Initial sync: Fetch all
        return await _fetchAllAndSave(prefs);
      } else {
        // Incremental sync
        if (lastUpdated == null) {
          // Fallback if box has data but no timestamp
          return await _fetchAllAndSave(prefs);
        }
        return await _syncIncremental(prefs, lastUpdated);
      }
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  Future<String> _fetchAllAndSave(SharedPreferences prefs) async {
    final response = await _supabase
        .from('manpower')
        .select('nrp, nama, sid_code, position, email, updated_at');

    final List<dynamic> data = response as List<dynamic>;
    if (data.isEmpty) return 'No manpower data found.';

    await _box.clear();
    final models = data.map((json) => ManpowerModel.fromJson(json)).toList();
    
    // Save to Hive
    final Map<String, ManpowerModel> map = {
      for (var m in models) m.nrp: m,
    };
    await _box.putAll(map);

    // Update max updated_at
    await _updateLastTimestamp(prefs, models);

    return 'Full sync completed. ${models.length} records downloaded.';
  }

  Future<String> _syncIncremental(
    SharedPreferences prefs,
    DateTime lastUpdated,
  ) async {
    // Check count of new records
    final countResponse = await _supabase
        .from('manpower')
        .select('nrp') // minimal select for count
        .gt('updated_at', lastUpdated.toIso8601String())
        .count(CountOption.exact);
    
    final count = countResponse.count;

    if (count == 0) {
      return 'Data is up to date.';
    }

    // Fetch new records
    final response = await _supabase
        .from('manpower')
        .select('nrp, nama, sid_code, position, email, updated_at')
        .gt('updated_at', lastUpdated.toIso8601String());

    final List<dynamic> data = response as List<dynamic>;
    final models = data.map((json) => ManpowerModel.fromJson(json)).toList();

    // Append/Update Hive
    final Map<String, ManpowerModel> map = {
      for (var m in models) m.nrp: m,
    };
    await _box.putAll(map);

    // Update max updated_at
    await _updateLastTimestamp(prefs, models);

    return 'Synced ${models.length} new/updated records.';
  }

  Future<void> _updateLastTimestamp(
    SharedPreferences prefs,
    List<ManpowerModel> models,
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
  Future<List<ManpowerEntity>> getFuelmen() async {
    return _box.values
        .where((m) => m.position == 5)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<List<ManpowerEntity>> getOperators() async {
    return _box.values
        .where((m) => m.position == 4)
        .map((m) => m.toEntity())
        .toList();
  }
}
