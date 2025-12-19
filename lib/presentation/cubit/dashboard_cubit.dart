import 'dart:convert';


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/dashboard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final LotoRepository lotoRepo;

  DashboardCubit(this.lotoRepo)
      : super(DashboardState(
          selectedDate: DateTime.now(),
          selectedShift: 0, // Default to Trend (Average Only)
        ));

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
        
        final lotoList = (decoded['loto'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final warehouseList = (decoded['warehouse'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        final nrpList = (decoded['nrp'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        
        _processAndEmit(lotoList, warehouseList, nrpList);
      } catch (e) {
        print("Error parsing dashboard cache: $e");
        throw e; // trigger re-fetch
      }
  }

  Future<void> _fetchAndSave(SharedPreferences prefs) async {
       try {
         // Insight 1: Loto Trend
         final lotoData = await lotoRepo.getAchievementTrend(daysBack: 30);
         // Insight 2: Warehouse (RPC)
         final warehouseData = await lotoRepo.getWarehouseAchievement(daysBack: 30);
         // Insight 3: NRP (RPC)
         final nrpData = await lotoRepo.getNrpRanking(daysBack: 30);
         
         final cacheMap = {
           'loto': lotoData,
           'warehouse': warehouseData,
           'nrp': nrpData,
         };
         
         await prefs.setString('dashboard_data', jsonEncode(cacheMap));
         await prefs.setInt('last_dashboard_load', DateTime.now().millisecondsSinceEpoch);
         
         _processAndEmit(lotoData, warehouseData, nrpData);
       } catch (e) {
         print("Error fetching dashboard data: $e");
         emit(state.copyWith(isLoading: false)); 
       }
  }

  void _processAndEmit(
      List<Map<String, dynamic>> lotoRawData,
      List<Map<String, dynamic>> warehouseRawData,
      List<Map<String, dynamic>> nrpRawData,
  ) {
    // 1. Process LOTO Data (buckets S1/S2)
    List<Map<String, dynamic>> s1 = [];
    List<Map<String, dynamic>> s2 = [];
    
    int daysToShow = 7;
    if (state.selectedPeriod == DashboardPeriod.month) {
       daysToShow = 30; 
    }
    
    final cutoff = DateTime.now().subtract(Duration(days: daysToShow));
    final allDates = lotoRawData
        .map((e) => e['date'] as String)
        .toSet()
        .map((e) => DateTime.parse(e))
        .where((d) => d.isAfter(cutoff))
        .toList();
    allDates.sort();

    List<DateTime> dateRange = [];
    for (int i = daysToShow - 1; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      dateRange.add(DateTime(d.year, d.month, d.day));
    }

    int dayIndex = 1;
    for (final date in dateRange) {
        final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
        
        // Find S1
        final entryS1 = lotoRawData.firstWhere(
            (e) => e['date'] == dateStr && e['shift'] == 1, 
            orElse: () => <String, dynamic>{},
        );
        double valS1 = entryS1.isNotEmpty ? (entryS1['percentage'] as num).toDouble() : 0.0;
        
        // Find S2
        final entryS2 = lotoRawData.firstWhere(
            (e) => e['date'] == dateStr && e['shift'] == 2, 
            orElse: () => <String, dynamic>{},
        );
        double valS2 = entryS2.isNotEmpty ? (entryS2['percentage'] as num).toDouble() : 0.0;
        
        s1.add({'day': dayIndex, 'count': valS1});
        s2.add({'day': dayIndex, 'count': valS2});
        dayIndex++;
    }

    // 2. Process Warehouse Data
    // RPC returns: warehouse_code, percentage
    List<Map<String, dynamic>> wData = warehouseRawData.map((e) => {
      'label': e['warehouse_code'] ?? 'Unknown',
      'value': (e['percentage'] as num).toDouble(),
    }).toList();
    // Sort Descending
    wData.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    // 3. Process NRP Data
    // RPC returns: nrp, name, percentage, loto_count, verification_count
    // We display Achievement % directly.

    List<Map<String, dynamic>> nData = nrpRawData.map((e) => {
      'label': e['name'] ?? e['nrp'] ?? 'Unknown',
      'value': (e['percentage'] as num).toDouble(),
    }).toList();
    
    // Sort Descending
    nData.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    emit(state.copyWith(
      isLoading: false,
      shift1Data: s1,
      shift2Data: s2,
      warehouseData: wData,
      nrpData: nData,
    ));
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
      final checkpoint1 = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 10, 0); // 18:00 WITA
      final checkpoint2 = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 22, 0); // 06:00 WITA (Next day really)
      // Checkpoints yesterday:
      final checkpoint1_prev = checkpoint1.subtract(const Duration(days: 1));
      final checkpoint2_prev = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day - 1, 22, 0); // Yesterday 06:00 WITA? No.
           
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
    
    emit(state.copyWith(
      selectedDate: date,
      selectedShift: shift,
      selectedPeriod: period,
    ));
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
