abstract class UnitState {}

class UnitInitial extends UnitState {}

class UnitLoading extends UnitState {}

class UnitLoaded extends UnitState {
  final List<String> units;
  UnitLoaded(this.units);
}

class UnitError extends UnitState {
  final String message;
  UnitError(this.message);
}
