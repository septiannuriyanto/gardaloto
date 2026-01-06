import 'package:equatable/equatable.dart';

class ManpowerEntity extends Equatable {
  final String nrp;
  final String? nama;
  final String? sidCode;
  final int? position;
  final String? email;
  final DateTime? updatedAt;

  final String? photoUrl;

  const ManpowerEntity({
    required this.nrp,
    this.nama,
    this.sidCode,
    this.position,
    this.email,
    this.updatedAt,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [
    nrp,
    nama,
    sidCode,
    position,
    email,
    updatedAt,
    photoUrl,
  ];
}
