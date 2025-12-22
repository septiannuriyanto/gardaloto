import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/dashboard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final LotoRepository lotoRepo;

  DashboardCubit(this.lotoRepo)
    : super(
        DashboardState(
          selectedDate: DateTime.now(),
          selectedShift: 0, // Default to Trend (Average Only)
        ),
      );

  static int _calculateShift(DateTime date) {
    final hour = date.hour;
    // Shift 1: 06:00 - 18:00
    if (hour >= 6 && hour < 18) {
      return 1;
    }
    return 2;
  }

  Future<void> loadData({bool force = false, bool silent = false}) async {
    if (!silent) emit(state.copyWith(isLoading: true));

    final prefs = await SharedPreferences.getInstance();
    final shouldRefresh = _shouldRefresh(prefs) || force;
    final cachedData = prefs.getString('dashboard_data');

    if (!shouldRefresh && cachedData != null && !force) {
      // Load from Cache
      try {
        await _emitCached(cachedData);
      } catch (e) {
        // Cache corrupted, fetch
        await _fetchAndSave(prefs);
      }
    } else {
      // Fetch Refresh
      await _fetchAndSave(prefs);
    }
  }

  Future<void> _emitCached(String cachedJson) async {
    try {
      final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;

      final lotoList =
          (decoded['loto'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      final warehouseList =
          (decoded['warehouse'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      final nrpList =
          (decoded['nrp'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      final lastVerificationCode = decoded['last_verification_code'] as int?;

      _processAndEmit(lotoList, warehouseList, nrpList, lastVerificationCode);
    } catch (e) {
      print("Error parsing dashboard cache: $e");
      throw e; // trigger re-fetch
    }
  }

  Future<void> _fetchAndSave(SharedPreferences prefs) async {
    try {
      // Determine range based on current selection
      // If user wants Week, we specifically fetch 7 days for Warehouse/NRP to match label
      // But we ALWAYS fetch 30 days for Loto Trend to keep the chart scrollable/rich.

      // 1. Loto Trend (Always 30 days for chart history)
      final lotoData = await lotoRepo.getAchievementTrend(daysBack: 30);

      // 2. Warehouse & NRP (Context-aware)
      // Calculate days back based on period. Default to 30 if null.
      int daysBack = state.selectedPeriod == DashboardPeriod.week ? 7 : 30;

      final warehouseData = await lotoRepo.getWarehouseAchievement(
        daysBack: daysBack,
      );
      final nrpData = await lotoRepo.getNrpRanking(daysBack: daysBack);
      final lastVerificationCode =
          await lotoRepo.getLastVerificationSessionCode();

      // Cache with specific key for the period to avoid mixing Week/Month data
      final periodKey =
          state.selectedPeriod == DashboardPeriod.week ? 'week' : 'month';
      final cacheKey = 'dashboard_data_$periodKey';

      final cacheMap = {
        'loto': lotoData,
        'warehouse': warehouseData,
        'nrp': nrpData,
        'last_verification_code': lastVerificationCode,
        'period': periodKey,
      };

      await prefs.setString(cacheKey, jsonEncode(cacheMap));
      // We also save to generic 'dashboard_data' for backward compat or initial load
      await prefs.setString('dashboard_data', jsonEncode(cacheMap));

      await prefs.setInt(
        'last_dashboard_load',
        DateTime.now().millisecondsSinceEpoch,
      );

      _processAndEmit(lotoData, warehouseData, nrpData, lastVerificationCode);
    } catch (e) {
      print("Error fetching dashboard data: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  void _processAndEmit(
    List<Map<String, dynamic>> lotoRawData,
    List<Map<String, dynamic>> warehouseRawData,
    List<Map<String, dynamic>> nrpRawData,
    int? lastVerificationCode,
  ) {
    // 1. Process LOTO Data (buckets S1/S2)
    // We always have 30 days of data here from lotoRawData
    // We filter visually based on daysToShow
    List<Map<String, dynamic>> s1 = [];
    List<Map<String, dynamic>> s2 = [];

    int daysToShow = state.selectedPeriod == DashboardPeriod.week ? 7 : 30;

    // ... Date buckets ...
    List<DateTime> dateRange = [];
    // Start from 1, exclude today (0)
    for (int i = daysToShow; i >= 1; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      dateRange.add(DateTime(d.year, d.month, d.day));
    }

    int dayIndex = 1;
    for (final date in dateRange) {
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final entryS1 = lotoRawData.firstWhere(
        (e) => e['date'] == dateStr && e['shift'] == 1,
        orElse: () => <String, dynamic>{},
      );
      double valS1 =
          entryS1.isNotEmpty ? (entryS1['percentage'] as num).toDouble() : 0.0;

      final entryS2 = lotoRawData.firstWhere(
        (e) => e['date'] == dateStr && e['shift'] == 2,
        orElse: () => <String, dynamic>{},
      );
      double valS2 =
          entryS2.isNotEmpty ? (entryS2['percentage'] as num).toDouble() : 0.0;

      s1.add({'day': dayIndex, 'count': valS1, 'date': date});
      s2.add({'day': dayIndex, 'count': valS2, 'date': date});
      dayIndex++;
    }

    // 2. Process Warehouse Data
    // RPC data is already pre-filtered by _fetchAndSave (7 or 30 days)
    List<Map<String, dynamic>> wData =
        warehouseRawData
            .map(
              (e) => {
                'label': e['warehouse_code'] ?? 'Unknown',
                'value': (e['percentage'] as num).toDouble(),
              },
            )
            .toList();
    wData.sort(
      (a, b) => (b['value'] as double).compareTo(a['value'] as double),
    );

    // 3. Process NRP Data
    // Also pre-filtered
    List<Map<String, dynamic>> nData =
        nrpRawData
            .map(
              (e) => {
                'label': e['name'] ?? e['nrp'] ?? 'Unknown',
                'nrp': e['nrp'], // Added for navigation
                'value': (e['percentage'] as num).toDouble(),
                'display_count':
                    e.containsKey('loto_count')
                        ? '${e['loto_count']} Records'
                        : null,
              },
            )
            .toList();

    nData.sort(
      (a, b) => (b['value'] as double).compareTo(a['value'] as double),
    );

    emit(
      state.copyWith(
        isLoading: false,
        shift1Data: s1,
        shift2Data: s2,
        warehouseData: wData,
        nrpData: nData,
        lastVerificationCode: lastVerificationCode,
      ),
    );
  }

  bool _shouldRefresh(SharedPreferences prefs) {
    final lastLoadMillis = prefs.getInt('last_dashboard_load');
    if (lastLoadMillis == null) return true;

    final lastLoad = DateTime.fromMillisecondsSinceEpoch(lastLoadMillis);
    // Ensure we compare in Local Time (GMT+8 assumption by user, using .now() is device time)
    // If user device is set to Jakarta (GMT+7) but wants GMT+8 rules?
    // "gunakan lastLotoDataLoaded agar rpc diload setiap jam 6 dan jam 18:00 wita"
    // WITA is GMT+8.
    // We will assume device time is WITA or we adjust.
    // Safer: Use UTC for logic. 06:00 WITA = 22:00 UTC (prev day). 18:00 WITA = 10:00 UTC.

    final nowUtc = DateTime.now().toUtc();
    final lastUtc = lastLoad.toUtc();

    // Determine the most recent "Checkpoint" (22:00 or 10:00 UTC)
    // Checkpoints today:
    final checkpoint1 = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      10,
      0,
    ); // 18:00 WITA
    final checkpoint2 = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      22,
      0,
    ); // 06:00 WITA (Next day really)
    // Checkpoints yesterday:
    final checkpoint1_prev = checkpoint1.subtract(const Duration(days: 1));
    final checkpoint2_prev = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day - 1,
      22,
      0,
    ); // Yesterday 06:00 WITA? No.

    // Let's simplify:
    // We have two daily sync times: 06:00 and 18:00 (Local/WITA).
    // If `lastLoad` was BEFORE the most recent sync time, and NOW is AFTER it, we refresh.
    // We need to convert to WITA (UTC+8).
    final nowWita = nowUtc.add(const Duration(hours: 8));
    final lastWita = lastUtc.add(const Duration(hours: 8));

    // Construct today's checkpoints in WITA
    final today06 = DateTime(nowWita.year, nowWita.month, nowWita.day, 6, 0);
    final today18 = DateTime(nowWita.year, nowWita.month, nowWita.day, 18, 0);

    DateTime targetCheckpoint;

    if (nowWita.isAfter(today18)) {
      targetCheckpoint = today18; // Latest was today 18:00
    } else if (nowWita.isAfter(today06)) {
      targetCheckpoint = today06; // Latest was today 06:00
    } else {
      // Before 06:00, so latest was yesterday 18:00
      targetCheckpoint = today18.subtract(const Duration(days: 1));
    }

    return lastWita.isBefore(targetCheckpoint);
  }

  void updateFilter({DateTime? date, int? shift, DashboardPeriod? period}) {
    // If period changes, we want seamless transition (silent=true)
    final silent = period != null;

    emit(
      state.copyWith(
        selectedDate: date,
        selectedShift: shift,
        selectedPeriod: period,
      ),
    );
    loadData(silent: silent);
  }
}

class DateUtils {
  static int getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }
}
