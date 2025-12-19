class UserEntity {
  final String id;
  final String email;
  final String? nrp;
  final String? nama;
  final DateTime? activeDate;
  final int? position;
  final String? sidCode;
  final String? photoUrl;
  final String? bgPhotoUrl;
  final String? positionDescription;

  UserEntity({
    required this.id,
    required this.email,
    this.nrp,
    this.nama,
    this.activeDate,
    this.position,
    this.sidCode,
    this.photoUrl,
    this.bgPhotoUrl,
    this.positionDescription,
  });
}
