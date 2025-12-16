import 'package:hive/hive.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';

class StorageModel extends HiveObject {
  final String warehouseId;
  final String? unitId;
  final String? status;
  final DateTime? updatedAt;

  StorageModel({
    required this.warehouseId,
    this.unitId,
    this.status,
    this.updatedAt,
  });

  factory StorageModel.fromEntity(StorageEntity entity) {
    return StorageModel(
      warehouseId: entity.warehouseId,
      unitId: entity.unitId,
      status: entity.status,
      updatedAt: entity.updatedAt,
    );
  }

  StorageEntity toEntity() {
    return StorageEntity(
      warehouseId: warehouseId,
      unitId: unitId,
      status: status,
      updatedAt: updatedAt,
    );
  }

  factory StorageModel.fromJson(Map<String, dynamic> json) {
    return StorageModel(
      warehouseId: json['warehouse_id'] as String,
      unitId: json['unit_id'] as String?,
      status: json['status'] as String?,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String)
              : null,
    );
  }
}

class StorageModelAdapter extends TypeAdapter<StorageModel> {
  @override
  final int typeId = 2;

  @override
  StorageModel read(BinaryReader reader) {
    final warehouseId = reader.readString();
    return StorageModel(
      warehouseId: warehouseId,
      unitId: reader.read(),
      status: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, StorageModel obj) {
    writer.writeString(obj.warehouseId);
    writer.write(obj.unitId);
    writer.write(obj.status);
    writer.write(obj.updatedAt);
  }
}
