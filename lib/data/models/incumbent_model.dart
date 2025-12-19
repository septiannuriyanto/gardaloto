import 'package:gardaloto/domain/entities/incumbent_entity.dart';

class IncumbentModel extends IncumbentEntity {
  const IncumbentModel({
    required super.id,
    required super.incumbent,
  });

  factory IncumbentModel.fromJson(Map<String, dynamic> json) {
    return IncumbentModel(
      id: json['id'] as int,
      incumbent: json['incumbent'] as String,
    );
  }
}
