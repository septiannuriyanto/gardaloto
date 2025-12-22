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
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
    final keysToDelete =
        _box.values
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
      final imageUrls = <Map<String, String?>>[];
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
        final fileNameThumb = '${record.codeNumber}-thumbnail.jpg';

        final filePath = '$imagePathPrefix/$fileName';
        final filePathThumb = '$imagePathPrefix/$fileNameThumb';

        // 1. Upload Original Image
        await _supabaseClient.storage
            .from('loto_records')
            .upload(
              filePath,
              File(record.photoPath),
              fileOptions: const FileOptions(upsert: true),
            );

        // 2. Generate and Upload Thumbnail
        // Generate a thumbnail with width ~300px
        final thumbnailFile = await FlutterImageCompress.compressAndGetFile(
          record.photoPath,
          record.photoPath.replaceAll('.jpg', '_thumb.jpg'),
          minWidth: 150,
          minHeight: 150,
          quality: 50, // Target ~10KB size
        );

        String? thumbUrl;

        if (thumbnailFile != null) {
          // Upload Thumbnail
          await _supabaseClient.storage
              .from('loto_records')
              .upload(
                filePathThumb,
                File(thumbnailFile.path),
                fileOptions: const FileOptions(upsert: true),
              );

          // Get Public URL for Thumbnail
          thumbUrl = _supabaseClient.storage
              .from('loto_records')
              .getPublicUrl(filePathThumb);

          // Clean up temporary thumbnail file
          await File(thumbnailFile.path).delete();
        }

        // Get the public URL for the uploaded original image
        final imageUrl = _supabaseClient.storage
            .from('loto_records')
            .getPublicUrl(filePath);

        imageUrls.add({'original': imageUrl, 'thumbnail': thumbUrl});

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
                  'photo_path': imageUrls[e.key]['original'],
                  'thumbnail_url': imageUrls[e.key]['thumbnail'],
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
      query = query
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());
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

    return (response as List)
        .map((e) => LotoModel.fromJson(e).toEntity())
        .toList();
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

        // Upload the image file to Supabase Storage with the proper path
        // We use the already processed (resized & watermarked) image from local storage
        await _supabaseClient.storage
            .from('loto_records')
            .upload(
              filePath,
              File(record.photoPath),
              fileOptions: const FileOptions(upsert: true),
            );

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

  @override
  Future<List<Map<String, dynamic>>> getAchievementTrend({
    int daysBack = 30,
  }) async {
    try {
      final data = await _supabaseClient.rpc(
        'get_loto_achievement_trend',
        params: {'days_back': daysBack},
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching achievement trend: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWarehouseAchievement({
    int daysBack = 30,
  }) async {
    try {
      final data = await _supabaseClient.rpc(
        'get_loto_achievement_warehouse',
        params: {'days_back': daysBack},
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching warehouse achievement: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getNrpRanking({int daysBack = 30}) async {
    try {
      final data = await _supabaseClient.rpc(
        'get_loto_ranking_nrp',
        params: {'days_back': daysBack},
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching nrp ranking: $e');
      return [];
    }
  }

  @override
  Future<int?> getLastVerificationSessionCode() async {
    try {
      final data = await _supabaseClient.rpc('get_max_session_code');
      // data might be null if no records, or the bigint value
      if (data == null) return null;
      return data is int ? data : int.tryParse(data.toString());
    } catch (e) {
      print('Error fetching max session code: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFuelmanDailyAchievement(
    String nrp, {
    int daysBack = 30,
  }) async {
    try {
      final data = await _supabaseClient.rpc(
        'get_fuelman_daily_achievement',
        params: {'p_nrp': nrp, 'days_back': daysBack},
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching fuelman daily achievement: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFuelmanReconciliation(
    String nrp,
    DateTime date,
    int shift,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0]; // "YYYY-MM-DD"
      final data = await _supabaseClient.rpc(
        'get_fuelman_reconciliation',
        params: {'p_nrp': nrp, 'p_date': dateStr, 'p_shift': shift},
      );
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error fetching fuelman reconciliation: $e');
      return [];
    }
  }

  @override
  Future<void> updateLotoRecordUnit(String recordId, String newUnitCode) async {
    try {
      await _supabaseClient.rpc(
        'update_loto_record_unit',
        params: {'p_record_id': recordId, 'p_new_unit_code': newUnitCode},
      );
    } catch (e) {
      print('Error updating loto record unit: $e');
      rethrow;
    }
  }
}
