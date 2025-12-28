import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/data/datasources/loto_uploader.dart';

class SupabaseLotoUploader implements LotoUploader {
  final SupabaseClient _supabaseClient;

  SupabaseLotoUploader(this._supabaseClient);

  @override
  Future<String> upload({
    required File file,
    required String path,
    required LotoSession session,
    required LotoEntity record,
    required bool isThumbnail,
  }) async {
    // Original logic: Upload to 'loto_records' bucket using the provided path
    await _supabaseClient.storage
        .from('loto_records')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    // Get public URL
    final publicUrl = _supabaseClient.storage
        .from('loto_records')
        .getPublicUrl(path);

    return publicUrl;
  }
}
