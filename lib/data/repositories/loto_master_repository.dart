import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardaloto/domain/entities/loto_master_record.dart';

class LotoMasterRepository {
  static const _kKey = 'loto_master_record';

  final SharedPreferences _prefs;

  LotoMasterRepository._(this._prefs);

  static Future<LotoMasterRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LotoMasterRepository._(prefs);
  }

  LotoMasterRecord? getMaster() {
    final raw = _prefs.getString(_kKey);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return LotoMasterRecord.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMaster(LotoMasterRecord record) async {
    final raw = jsonEncode(record.toJson());
    await _prefs.setString(_kKey, raw);
  }

  Future<void> clear() async {
    await _prefs.remove(_kKey);
  }
}
