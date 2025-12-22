class LotoEntity {
  final String codeNumber;
  final String photoPath;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String sessionId;
  final String? thumbnailUrl;

  LotoEntity({
    required this.codeNumber,
    required this.photoPath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.sessionId,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'code_number': codeNumber,
      'photo_path': photoPath,
      'timestamp_taken': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'session_id': sessionId,
      'thumbnail_url': thumbnailUrl,
    };
  }

  factory LotoEntity.fromJson(Map<String, dynamic> json) {
    return LotoEntity(
      codeNumber: json['code_number'] as String,
      photoPath: json['photo_path'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      sessionId: json['session_id'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}
