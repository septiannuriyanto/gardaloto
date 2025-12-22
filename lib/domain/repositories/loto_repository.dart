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

  /// Fetches the LOTO achievement trend (RPC get_loto_achievement_trend).
  /// Returns a list of maps containing date, shift, and percentage.
  Future<List<Map<String, dynamic>>> getAchievementTrend({int daysBack = 30});

  /// Fetches Warehouse achievement (RPC get_loto_achievement_warehouse).
  Future<List<Map<String, dynamic>>> getWarehouseAchievement({
    int daysBack = 30,
  });

  /// Fetches NRP Ranking (RPC get_loto_ranking_nrp).
  Future<List<Map<String, dynamic>>> getNrpRanking({int daysBack = 30});

  /// Get the max session code from loto_verification table
  /// Returns a big int like YYMMDDSSSS or null
  Future<int?> getLastVerificationSessionCode();

  /// Fetches daily achievement for a specific fuelman (RPC get_fuelman_daily_achievement).
  Future<List<Map<String, dynamic>>> getFuelmanDailyAchievement(
    String nrp, {
    int daysBack = 30,
  });

  /// Fetches reconciliation list for a specific fuelman/date/shift (RPC get_fuelman_reconciliation).
  Future<List<Map<String, dynamic>>> getFuelmanReconciliation(
    String nrp,
    DateTime date,
    int shift,
  );

  /// Updates the unit code of an existing LOTO record (RPC update_loto_record_unit).
  Future<void> updateLotoRecordUnit(String recordId, String newUnitCode);
}
