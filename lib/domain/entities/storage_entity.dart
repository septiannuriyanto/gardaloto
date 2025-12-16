import 'package:equatable/equatable.dart';

class StorageEntity extends Equatable {
  final String warehouseId;
  final String? unitId;
  final String? status;
  final DateTime? updatedAt;

  const StorageEntity({
    required this.warehouseId,
    this.unitId,
    this.status,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [warehouseId, unitId, status, updatedAt];
}
