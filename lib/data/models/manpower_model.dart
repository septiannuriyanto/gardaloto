import 'package:hive/hive.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';

class ManpowerModel extends HiveObject {
  final String nrp;
  final String? nama;
  final String? sidCode;
  final int? position;
  final String? email;
  final DateTime? updatedAt;

  ManpowerModel({
    required this.nrp,
    this.nama,
    this.sidCode,
    this.position,
    this.email,
    this.updatedAt,
  });

  factory ManpowerModel.fromEntity(ManpowerEntity entity) {
    return ManpowerModel(
      nrp: entity.nrp,
      nama: entity.nama,
      sidCode: entity.sidCode,
      position: entity.position,
      email: entity.email,
      updatedAt: entity.updatedAt,
    );
  }

  ManpowerEntity toEntity() {
    return ManpowerEntity(
      nrp: nrp,
      nama: nama,
      sidCode: sidCode,
      position: position,
      email: email,
      updatedAt: updatedAt,
    );
  }

  factory ManpowerModel.fromJson(Map<String, dynamic> json) {
    return ManpowerModel(
      nrp: json['nrp'] as String,
      nama: json['nama'] as String?,
      sidCode: json['sid_code'] as String?,
      position: json['position'] as int?,
      email: json['email'] as String?,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String)
              : null,
    );
  }
}

class ManpowerModelAdapter extends TypeAdapter<ManpowerModel> {
  @override
  final int typeId = 1;

  @override
  ManpowerModel read(BinaryReader reader) {
    final nrp = reader.readString();
    return ManpowerModel(
      nrp: nrp,
      nama: reader.read(),
      sidCode: reader.read(),
      position: reader.read(),
      email: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ManpowerModel obj) {
    writer.writeString(obj.nrp);
    writer.write(obj.nama);
    writer.write(obj.sidCode);
    writer.write(obj.position);
    writer.write(obj.email);
    writer.write(obj.updatedAt);
  }
}
