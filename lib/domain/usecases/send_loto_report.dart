import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';

class SendLotoReport {
  final LotoRepository repository;

  SendLotoReport(this.repository);

  Future<UploadResult> call(
    LotoSession session,
    List<LotoEntity> records, {
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      await repository.sendReport(session, records, onProgress: onProgress);
      return UploadResult.success(message: 'Upload completed successfully');
    } catch (e) {
      return UploadResult.error(message: 'Upload failed: $e');
    }
  }
}

class UploadResult {
  final bool isSuccess;
  final String message;

  UploadResult._(this.isSuccess, this.message);

  factory UploadResult.success({required String message}) =>
      UploadResult._(true, message);

  factory UploadResult.error({required String message}) =>
      UploadResult._(false, message);
}
