import 'dart:convert';
import 'package:gardaloto/domain/repositories/unit_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnitRepositoryImpl implements UnitRepository {
  final SupabaseClient _supabase;
  static const _kUnitCacheKey = 'unit_cache_key';
  static const _kLastUpdatedKey = 'unit_cache_last_updated';
  static const _kCacheDuration = Duration(hours: 1); // Refresh every hour if valid

  UnitRepositoryImpl(this._supabase);

  @override
  Future<List<String>> getUnits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdatedStr = prefs.getString(_kLastUpdatedKey);
      final jsonCache = prefs.getString(_kUnitCacheKey);

      if (jsonCache != null && lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr);
        final difference = DateTime.now().difference(lastUpdated);

        // If cache is fresh, return it
        if (difference < _kCacheDuration) {
          final List<dynamic> decoded = jsonDecode(jsonCache);
          return decoded.cast<String>();
        }
      }

      // If cache is stale or missing, fetch from RPC
      return await _fetchFromRpc(prefs);
    } catch (e) {
      // On error (e.g. network), try to fallback to cache even if stale
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonCache = prefs.getString(_kUnitCacheKey);
        if (jsonCache != null) {
          final List<dynamic> decoded = jsonDecode(jsonCache);
          return decoded.cast<String>();
        }
      } catch (_) {}
      
      // If all fails, throw or return empty
      // Throwing allows Cubit to handle error state
      throw Exception('Failed to fetch units: $e');
    }
  }

  Future<List<String>> _fetchFromRpc(SharedPreferences prefs) async {
    final response = await _supabase.rpc('get_unique_loto_units');
    
    // Response should be a List of strings (or dynamics that are strings)
    final List<dynamic> data = response as List<dynamic>;
    final List<String> units = data.cast<String>().toList();

    // Cache the result
    await prefs.setString(_kUnitCacheKey, jsonEncode(units));
    await prefs.setString(_kLastUpdatedKey, DateTime.now().toIso8601String());

    return units;
  }
}
