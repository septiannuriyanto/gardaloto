import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/repositories/manpower_repository.dart';

abstract class ManpowerState extends Equatable {
  const ManpowerState();
  @override
  List<Object?> get props => [];
}

class ManpowerInitial extends ManpowerState {}

class ManpowerSyncing extends ManpowerState {}

class ManpowerSynced extends ManpowerState {
  final String message;
  final List<ManpowerEntity> fuelmen;
  final List<ManpowerEntity> operators;

  const ManpowerSynced(this.message, this.fuelmen, this.operators);

  @override
  List<Object?> get props => [message, fuelmen, operators];
}

class ManpowerError extends ManpowerState {
  final String message;
  const ManpowerError(this.message);
  @override
  List<Object?> get props => [message];
}

class ManpowerCubit extends Cubit<ManpowerState> {
  final ManpowerRepository repo;

  ManpowerCubit(this.repo) : super(ManpowerInitial());

  Future<void> syncAndLoad() async {
    emit(ManpowerSyncing());
    try {
      final msg = await repo.syncManpower();
      final fuelmen = await repo.getFuelmen();
      final operators = await repo.getOperators();
      emit(ManpowerSynced(msg, fuelmen, operators));
    } catch (e) {
      // Even if sync fails, try to load local data
      try {
        final fuelmen = await repo.getFuelmen();
        final operators = await repo.getOperators();
        if (fuelmen.isNotEmpty || operators.isNotEmpty) {
           emit(ManpowerSynced('Sync failed: $e. Using local data.', fuelmen, operators));
           return;
        }
      } catch (_) {}
      
      emit(ManpowerError(e.toString()));
    }
  }
  
  Future<void> loadLocalOnly() async {
    try {
      final fuelmen = await repo.getFuelmen();
      final operators = await repo.getOperators();
      emit(ManpowerSynced('Loaded local data', fuelmen, operators));
    } catch (e) {
      emit(ManpowerError(e.toString()));
    }
  }
}
