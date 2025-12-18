import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/unit_repository.dart';
import 'package:gardaloto/presentation/cubit/unit_state.dart';

class UnitCubit extends Cubit<UnitState> {
  final UnitRepository _repository;

  UnitCubit(this._repository) : super(UnitInitial());

  Future<void> loadUnits() async {
    emit(UnitLoading());
    try {
      final units = await _repository.getUnits();
      emit(UnitLoaded(units));
    } catch (e) {
      emit(UnitError(e.toString()));
    }
  }
}
