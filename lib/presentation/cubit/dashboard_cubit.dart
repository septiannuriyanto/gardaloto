import 'dart:convert';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/dashboard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit()
      : super(DashboardState(
          selectedDate: DateTime.now(),
          selectedShift: _calculateShift(DateTime.now()),
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

    // If we have cache and don't need refresh, use cache (unless it's empty?)
    // But wait, if we switch Week/Month, cache might not match current filter.
    // For simplicity, let's assume 'dashboard_data' stores the FULL DATASET (e.g. Month)
    // and we filter in memory?
    // User requested "loading datanya jangan setiap kali...". 
    // This implies the *network fetch* is what we want to avoid.
    // Our 'dummy generation' simulates network fetch.
    
    if (!shouldRefresh && cachedData != null && !force) {
        // Load from Cache (Simulated)
        try {
            // For dummy data, we ignore the actual json content and just regenerate.
            // In a real app, we would parse `jsonDecode(cachedData)` and emit it.
            if (silent) {
                 _generateAndEmit(prefs);
            } else {
                 _emitCachedOrFast(prefs, cachedData);
            }
        } catch (e) {
            // Cache corrupted, fetch
            await _fetchAndSave(prefs);
        }
    } else {
        // Fetch Refresh
        await _fetchAndSave(prefs);
    }
  }

  Future<void> _emitCachedOrFast(SharedPreferences prefs, String cachedJson) async {
      // For dummy purposes, we just generate raw data again instantly
      _generateAndEmit(prefs);
  }

  Future<void> _fetchAndSave(SharedPreferences prefs) async {
       // Simulate Network Delay
       await Future.delayed(const Duration(seconds: 1));
       _generateAndEmit(prefs);
       
       // Save timestamp
       await prefs.setInt('last_dashboard_load', DateTime.now().millisecondsSinceEpoch);
       // Save "data" (dummy placeholder)
       await prefs.setString('dashboard_data', '{"dummy": true}'); 
  }

  void _generateAndEmit(SharedPreferences prefs) {
    final random = Random();
    List<Map<String, dynamic>> s1 = [];
    List<Map<String, dynamic>> s2 = [];
    
    // Loto Achievement Logic
    int days = 7;
    // If Month, use full month days. If Week, use 7.
    if (state.selectedPeriod == DashboardPeriod.month) {
       days = DateUtils.getDaysInMonth(state.selectedDate.year, state.selectedDate.month);
    } else {
       // For week, we assume 7 days.
       days = 7; 
    }
    
    for (int i = 1; i <= days; i++) {
        s1.add({'day': i, 'count': 50 + random.nextInt(50)}); 
        s2.add({'day': i, 'count': 40 + random.nextInt(60)});
    }
    
    List<Map<String, dynamic>> wData = [
      {'label': 'WH A', 'value': 85},
      {'label': 'WH B', 'value': 60},
      {'label': 'WH C', 'value': 90},
      {'label': 'WH D', 'value': 45},
      {'label': 'WH E', 'value': 75},
    ];
    // Sort Highest to Lowest
    wData.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));
    
    List<Map<String, dynamic>> nData = [
      {'label': 'A.S.', 'value': 95},
      {'label': 'B.K.', 'value': 88},
      {'label': 'C.D.', 'value': 72},
      {'label': 'D.E.', 'value': 99},
      {'label': 'E.F.', 'value': 65},
    ];
    // Sort Highest to Lowest
    nData.sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));

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
      final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // GMT+8
      
      // Check yesterday 21:00, today 09:00, today 21:00
      // We need to find the "latest scheduled point" before NOW.
      // If lastLoad < latestPoint, then Refresh.
      
      final today9 = DateTime(now.year, now.month, now.day, 9);
      final today21 = DateTime(now.year, now.month, now.day, 21);
      final yesterday21 = today21.subtract(const Duration(days: 1));

      DateTime targetPoint = yesterday21;
      if (now.isAfter(today21)) {
          targetPoint = today21;
      } else if (now.isAfter(today9)) {
          targetPoint = today9;
      }

      // We need to compare lastLoad (which might be local time converted to millis? 
      // DateTime.now() is Local. 
      // User said "semua timezone menggunakan GMT + 8".
      // Best to standardize storage as UTC or explicit GMT+8.
      // I'll assume stored millis are consistent (UTC).
      
      // Let's refactor to ensure consistency.
      final lastLoadGmt8 = lastLoad.toUtc().add(const Duration(hours: 8));
      
      // Actually simpler:
      // If lastLoad was before Today 9am and now is after Today 9am -> Refresh.
      // If lastLoad was before Today 9pm and now is after Today 9pm -> Refresh.
      
      return lastLoadGmt8.isBefore(targetPoint); 
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
