import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';

abstract class LotoRepository {
  Future<List<LotoEntity>> getLocalRecords();
  Future<void> saveLocal(LotoEntity entity);
  Future<void> deleteLocal(LotoEntity entity);
  Future<void> clearAllLocal();

  Future<void> deleteLocalSessionRecords(String sessionCode);

  Future<void> saveActiveSession(LotoSession session);
  Future<LotoSession?> getActiveSession();
  Future<void> clearActiveSession();

  /// Untuk autocomplete unit code
  Future<List<String>> fetchUnitCodes();

  /// Send LOTO report to Supabase
  Future<void> sendReport(
    LotoSession session,
    List<LotoEntity> records, {
    void Function(int count, int total)? onProgress,
  });

  /// Fetch past sessions with optional filters
  Future<List<LotoSession>> fetchSessions({
    DateTime? date,
    int? shift,
    String? warehouseCode,
    String? fuelman,
    String? operatorName,
    int limit = 10,
  });

  /// Fetch records for a specific session
  Future<List<LotoEntity>> fetchSessionRecords(String sessionCode);

  /// Get count of records in Supabase for a session
  Future<int> getRemoteRecordCount(String sessionCode);

  /// Get count of records in local Hive for a session
  Future<int> getLocalRecordCount(String sessionCode);

  /// Fetch local records for a specific session
  Future<List<LotoEntity>> getLocalSessionRecords(String sessionCode);

  Future<void> appendSessionRecords(
    LotoSession session,
    List<LotoEntity> records, {
    void Function(int count, int total)? onProgress,
  });

  /// Save last known location for fallback
  Future<void> saveLastKnownLocation(double lat, double lng);

  /// Get last known location
  Future<(double, double)?> getLastKnownLocation();
}
