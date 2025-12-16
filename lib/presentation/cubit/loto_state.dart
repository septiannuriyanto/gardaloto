import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';

sealed class LotoState {
  const LotoState();
}

class LotoInitial extends LotoState {}

class LotoLoading extends LotoState {}

class LotoLoaded extends LotoState {
  final List<LotoEntity> records;
  final LotoSession? session;

  /// When true, there is an in-flight operation (e.g., optimistic delete)
  /// and some UI actions (like showing the empty-list dialog) should wait
  /// until the operation completes to avoid race conditions.
  final bool isPendingOperation;

  LotoLoaded(this.records, {this.session, this.isPendingOperation = false});
}

class LotoCapturing extends LotoState {
  final String photoPath;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final LotoSession? session;
  final List<LotoEntity> records;

  final bool isLocationLoading;
  final String? locationError;
  final bool hasAttemptedGpsFetch;

  const LotoCapturing({
    required this.photoPath,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.session,
    this.records = const [],
    this.isLocationLoading = false,
    this.locationError,
    this.hasAttemptedGpsFetch = false,
  });

  List<Object?> get props => [
    photoPath,
    lat,
    lng,
    timestamp,
    session,
    records,
    isLocationLoading,
    locationError,
    hasAttemptedGpsFetch,
  ];
}

class LotoError extends LotoState {
  final String message;
  LotoError(this.message);
}

class LotoUploading extends LotoState {
  final int uploadedCount;
  final int totalCount;
  final LotoSession? session;
  final List<LotoEntity> records;

  LotoUploading({
    this.uploadedCount = 0,
    this.totalCount = 0,
    this.session,
    this.records = const [],
  });
}

class LotoUploadSuccess extends LotoState {
  final String message;
  final LotoSession? session;
  final List<LotoEntity> records;

  LotoUploadSuccess(this.message, {this.session, this.records = const []});
}

class LotoUploadError extends LotoState {
  final String message;
  final LotoSession? session;
  final List<LotoEntity> records;

  LotoUploadError(this.message, {this.session, this.records = const []});
}

class LotoSubmitting extends LotoState {
  final String message;

  const LotoSubmitting({this.message = 'Saving record...'});
}
