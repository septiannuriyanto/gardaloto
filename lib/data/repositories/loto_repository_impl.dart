import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/data/models/loto_model.dart';
import 'package:gardaloto/data/models/loto_model_adapter.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/core/image_utils.dart';

class LotoRepositoryImpl implements LotoRepository {
  static const _boxName = 'loto_records';
  late Box<LotoModel> _box;
  final SupabaseClient _supabaseClient;

  LotoRepositoryImpl(this._supabaseClient);

  /// Initialize Hive and open the box. Call this before using the repo.
  Future<void> init() async {
    await Hive.initFlutter();
    // Register adapter only once
    // Register adapter only once
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(LotoModelAdapter());
    try {
      _box = await Hive.openBox<LotoModel>(_boxName);
    } catch (e) {
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<LotoModel>(_boxName);
    }
  }

  @override
  Future<List<LotoEntity>> getLocalRecords() async {
    return _box.values.map((e) => e.toEntity()).toList();
  }

  @override
  Future<void> saveLocal(LotoEntity entity) async {
    final model = LotoModel.fromEntity(entity);
    // Use milliseconds to match Adapter precision and ensure consistent keys
    final key = entity.timestamp.millisecondsSinceEpoch.toString();
    await _box.put(key, model);
  }

  @override
  Future<void> deleteLocal(LotoEntity entity) async {
    // Use milliseconds to match Adapter precision and ensure consistent keys
    final key = entity.timestamp.millisecondsSinceEpoch.toString();
    await _box.delete(key);

    // try deleting the underlying file if exists
    try {
      final file = File(entity.photoPath);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // ignore file deletion errors
    }
  }

  @override
  Future<void> clearAllLocal() async {
    await _box.clear();
  }

  @override
  Future<void> deleteLocalSessionRecords(String sessionCode) async {
    final keysToDelete = _box.values
        .where((e) => e.sessionId == sessionCode)
        .map((e) => e.timestampTaken.millisecondsSinceEpoch.toString())
        .toList();
    
    await _box.deleteAll(keysToDelete);
  }

  @override
  Future<List<String>> fetchUnitCodes() async {
    return [];
  }

  @override
  Future<void> saveActiveSession(LotoSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = jsonEncode(session.toJson());
    await prefs.setString('active_session', sessionJson);
  }

  @override
  Future<LotoSession?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJsonString = prefs.getString('active_session');
    if (sessionJsonString == null) {
      return null;
    }
    final sessionJsonMap = jsonDecode(sessionJsonString);
    return LotoSession.fromJson(sessionJsonMap);
  }

  @override
  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session');
  }

  @override
  @override
  Future<void> sendReport(
    LotoSession session,
    List<LotoEntity> records, {
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      // Construct the path for the images based on the session data
      final year = session.dateTime.year.toString().padLeft(4, '0');
      final month = session.dateTime.month.toString().padLeft(2, '0');
      final day = session.dateTime.day.toString().padLeft(2, '0');
      final shift = session.shift.toString();
      final warehouse = session.warehouseCode;
      final imagePathPrefix = '$year/$month/$day/$shift/$warehouse';

      // First, upload all images to Supabase Storage
      final imageUrls = <String>[];
      int uploadedCount = 0;
      
      // Import image_utils for compression
      // Note: Since I cannot easily add imports here without messing up the file structure if I use replace_file_content on a small chunk, 
      // I will assume image_utils is available or I need to add the import.
      // Wait, I need to add the import first. I'll do that in a separate step or assume it's fine if I use the fully qualified name or just add the import now.
      // Actually, I should have added the import. Let me check imports.
      // I'll add the import in a separate tool call or just use the function if it's global (it is global in image_utils.dart).
      // But I need to import the file.
      
      for (final record in records) {
        // Use unit code as filename instead of timestamp
        final fileName = '${record.codeNumber}.jpg';
        final filePath = '$imagePathPrefix/$fileName';

        // Compress image
        // I need to import image_utils.dart. I will assume I can add the import at the top.
        // For now, I'll comment out the compression call and add it after I add the import.
        // actually, I can just use the tool to add import and then replace this.
        // But let's try to do it all here if possible.
        // I'll skip compression call here and do it in next step after adding import.
        
        // Compress image
        final compressedPath = await compressImage(inputPath: record.photoPath);

        // Upload the image file to Supabase Storage with the proper path
        await _supabaseClient.storage
            .from('loto_records')
            .upload(filePath, File(compressedPath));

        // Get the public URL for the uploaded image
        final imageUrl = _supabaseClient.storage
            .from('loto_records')
            .getPublicUrl(filePath);
        imageUrls.add(imageUrl);
        
        uploadedCount++;
        onProgress?.call(uploadedCount, records.length);
      }

      // Then, insert the session into the database
      await _supabaseClient.from('loto_sessions').insert(session.toJson());

      // Finally, insert the records into the database
      final recordData =
          records
              .asMap()
              .entries
              .map(
                (e) => {
                  ...e.value.toJson(),
                  'session_id':
                      session.nomor, // Add session_id from loto_sessions
                  'photo_path': imageUrls[e.key],
                },
              )
              .toList();
      await _supabaseClient.from('loto_records').insert(recordData);
    } catch (e) {
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }

  @override
  Future<List<LotoSession>> fetchSessions({
    DateTime? date,
    int? shift,
    String? warehouseCode,
    String? fuelman,
    String? operatorName,
    int limit = 10,
  }) async {
    var query = _supabaseClient.from('loto_sessions').select();

    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.gte('created_at', startOfDay.toIso8601String()).lt(
        'created_at',
        endOfDay.toIso8601String(),
      );
    }

    if (shift != null) {
      query = query.eq('create_shift', shift);
    }

    if (warehouseCode != null && warehouseCode.isNotEmpty) {
      query = query.eq('warehouse_code', warehouseCode);
    }

    if (fuelman != null && fuelman.isNotEmpty) {
      query = query.eq('fuelman', fuelman);
    }
    
    if (operatorName != null && operatorName.isNotEmpty) {
      query = query.eq('operator', operatorName);
    }

    // Apply order and limit at the end
    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
        
    return (response as List).map((e) => LotoSession.fromJson(e)).toList();
  }

  @override
  Future<List<LotoEntity>> fetchSessionRecords(String sessionCode) async {
    final response = await _supabaseClient
        .from('loto_records')
        .select()
        .eq('session_id', sessionCode)
        .order('timestamp_taken', ascending: true);

    return (response as List).map((e) => LotoModel.fromJson(e).toEntity()).toList();
  }

  @override
  Future<int> getRemoteRecordCount(String sessionCode) async {
    final response = await _supabaseClient
        .from('loto_records')
        .select()
        .eq('session_id', sessionCode)
        .count(CountOption.exact);
    
    // When using count, the response is a PostgrestResponse, but with select().count() 
    // it returns a list of objects if we don't use head: true.
    // Actually, select(count: exact) returns the data AND the count.
    // To get just count, we can use count() directly or check the count property if available.
    // In supabase_flutter v2, select().count() returns PostgrestFilterBuilder.
    // We need to await it. The result is PostgrestResponse<List<Map<String, dynamic>>>.
    // The count is in the `count` property of the response.
    // Wait, the return type of `await ...` is `List<Map<String, dynamic>>` usually, unless we use `.count()`.
    // Let's use `.count()` which returns `Future<int>`.
    
    return await _supabaseClient
        .from('loto_records')
        .count(CountOption.exact)
        .eq('session_id', sessionCode);
  }

  @override
  Future<int> getLocalRecordCount(String sessionCode) async {
    // In Hive, we store records. We need to filter by session_id.
    // However, currently `LotoModel` has `sessionId`.
    // But wait, `LotoRepositoryImpl` uses `_box` which stores `LotoModel`.
    // Does `LotoModel` have `sessionId`? Yes, I verified it.
    // But `saveLocal` saves with `timestamp` as key.
    // We need to iterate all values.
    return _box.values.where((e) => e.sessionId == sessionCode).length;
  }

  @override
  Future<List<LotoEntity>> getLocalSessionRecords(String sessionCode) async {
    return _box.values
        .where((e) => e.sessionId == sessionCode)
        .map((e) => e.toEntity())
        .toList();
  }

  @override
  Future<void> appendSessionRecords(
    LotoSession session,
    List<LotoEntity> records, {
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      // Construct the path for the images based on the session data
      final year = session.dateTime.year.toString().padLeft(4, '0');
      final month = session.dateTime.month.toString().padLeft(2, '0');
      final day = session.dateTime.day.toString().padLeft(2, '0');
      final shift = session.shift.toString();
      final warehouse = session.warehouseCode;
      final imagePathPrefix = '$year/$month/$day/$shift/$warehouse';

      // First, upload all images to Supabase Storage
      final imageUrls = <String>[];
      int uploadedCount = 0;

      for (final record in records) {
        // Use unit code as filename instead of timestamp
        final fileName = '${record.codeNumber}.jpg';
        final filePath = '$imagePathPrefix/$fileName';

        // Compress image
        final compressedPath = await compressImage(inputPath: record.photoPath);

        // Upload the image file to Supabase Storage with the proper path
        await _supabaseClient.storage
            .from('loto_records')
            .upload(filePath, File(compressedPath), fileOptions: const FileOptions(upsert: true));

        // Get the public URL for the uploaded image
        final imageUrl = _supabaseClient.storage
            .from('loto_records')
            .getPublicUrl(filePath);
        imageUrls.add(imageUrl);

        uploadedCount++;
        onProgress?.call(uploadedCount, records.length);
      }

      // Insert the records into the database
      final recordData =
          records
              .asMap()
              .entries
              .map(
                (e) => {
                  ...e.value.toJson(),
                  'session_id':
                      session.nomor, // Add session_id from loto_sessions
                  'photo_path': imageUrls[e.key],
                },
              )
              .toList();
      await _supabaseClient.from('loto_records').insert(recordData);
    } catch (e) {
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }


  @override
  Future<void> saveLastKnownLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_known_lat', lat);
    await prefs.setDouble('last_known_lng', lng);
  }

  @override
  Future<(double, double)?> getLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_known_lat');
    final lng = prefs.getDouble('last_known_lng');
    if (lat != null && lng != null) {
      return (lat, lng);
    }
    return null;
  }
}
