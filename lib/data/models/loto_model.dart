import 'package:gardaloto/domain/entities/loto_entity.dart';

class LotoModel {
  final String codeNumber;
  final String photoPath;
  final DateTime timestampTaken;
  final double latitude;
  final double longitude;
  final String sessionId;

  LotoModel({
    required this.codeNumber,
    required this.photoPath,
    required this.timestampTaken,
    required this.latitude,
    required this.longitude,
    required this.sessionId,
  });

  // ===============================
  // FROM SUPABASE (JSON)
  // ===============================
  factory LotoModel.fromJson(Map<String, dynamic> json) {
    return LotoModel(
      codeNumber: json['code_number'] as String,
      photoPath: json['photo_path'] as String,
      timestampTaken: DateTime.parse(json['timestamp_taken'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sessionId: json['session_id'] as String,
    );
  }

  // ===============================
  // TO SUPABASE (JSON)
  // ===============================
  Map<String, dynamic> toJson() {
    return {
      'code_number': codeNumber,
      'photo_path': photoPath,
      'timestamp_taken': timestampTaken.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'session_id': sessionId,
    };
  }

  // ===============================
  // ENTITY MAPPER
  // ===============================
  factory LotoModel.fromEntity(LotoEntity entity) {
    return LotoModel(
      codeNumber: entity.codeNumber,
      photoPath: entity.photoPath,
      timestampTaken: entity.timestamp,
      latitude: entity.latitude,
      longitude: entity.longitude,
      sessionId: entity.sessionId,
    );
  }

  LotoEntity toEntity() {
    return LotoEntity(
      codeNumber: codeNumber,
      photoPath: photoPath,
      timestamp: timestampTaken,
      latitude: latitude,
      longitude: longitude,
      sessionId: sessionId,
    );
  }
}
