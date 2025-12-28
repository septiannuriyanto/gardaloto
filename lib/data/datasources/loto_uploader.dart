import 'dart:io';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';

abstract class LotoUploader {
  /// Uploads an image and returns the public URL.
  /// [file] is the file to upload.
  /// [path] is the desired path/filename (used by Supabase).
  /// [session] and [record] provide metadata for the Worker/R2 structure.
  Future<String> upload({
    required File file,
    required String path,
    required LotoSession session,
    required LotoEntity record,
    required bool isThumbnail,
  });
}
