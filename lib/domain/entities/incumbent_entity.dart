import 'package:equatable/equatable.dart';

class IncumbentEntity extends Equatable {
  final int id;
  final String incumbent;

  const IncumbentEntity({
    required this.id,
    required this.incumbent,
  });

  @override
  List<Object?> get props => [id, incumbent];
}
