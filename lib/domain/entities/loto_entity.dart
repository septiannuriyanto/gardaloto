class LotoEntity {
  final String codeNumber;
  final String photoPath;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String sessionId;

  LotoEntity({
    required this.codeNumber,
    required this.photoPath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'code_number': codeNumber,
      'photo_path': photoPath,
      'timestamp_taken': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'session_id': sessionId,
    };
  }

  static LotoEntity fromJson(Map<String, dynamic> json) {
    return LotoEntity(
      codeNumber: json['code_number'] as String,
      photoPath: json['photo_path'] as String,
      timestamp: DateTime.parse(json['timestamp_taken'] as String),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      sessionId: json['session_id'] as String,
    );
  }
}
