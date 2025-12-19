import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/domain/entities/incumbent_entity.dart';
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

class ManpowerLoaded extends ManpowerState {
  final List<UserEntity> users;
  const ManpowerLoaded(this.users);
  
  @override
  List<Object?> get props => [users];
}

class ManpowerCubit extends Cubit<ManpowerState> {
  final ManpowerRepository repo;

  ManpowerCubit(this.repo) : super(ManpowerInitial());

  Future<void> syncAndLoad() async {
    emit(ManpowerSyncing());
    try {
      await repo.syncManpower();
      final fuelmen = await repo.getFuelmen();
      final operators = await repo.getOperators();
      emit(ManpowerSynced('Synced successfully', fuelmen, operators));
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

  // === USER MANAGEMENT ===
  Future<void> fetchAllUsers() async {
    emit(ManpowerSyncing()); // Reuse syncing state or create Loading
    try {
      final users = await repo.getAllUsers();
      emit(ManpowerLoaded(users));
    } catch (e) {
      emit(ManpowerError(e.toString()));
    }
  }

  Future<void> toggleUserStatus(String nrp, bool isActive) async {
    try {
      await repo.toggleUserStatus(nrp, isActive);
      await fetchAllUsers();
    } catch (e) {
      emit(ManpowerError(e.toString()));
    }
  }

  Future<void> unregisterUser(String nrp) async {
    try {
      await repo.unregisterUser(nrp);
      await fetchAllUsers();
    } catch (e) {
       emit(ManpowerError(e.toString()));
    }
  }

  Future<void> updateUser(UserEntity user) async {
    try {
       emit(ManpowerSyncing());
       await repo.updateUser(user);
       await fetchAllUsers();
    } catch (e) {
       emit(ManpowerError(e.toString()));
    }
  }

  Future<void> deleteUser(String nrp) async {
    try {
      await repo.deleteUser(nrp);
      await fetchAllUsers();
    } catch (e) {
      emit(ManpowerError(e.toString()));
    }
  }
  
  Future<List<IncumbentEntity>> getIncumbents() async {
     return await repo.getIncumbents();
  }

  Future<void> addNewUser(String nrp) async {
    final previousState = state;
    try {
      await repo.addManpower(nrp);
      await fetchAllUsers();
    } catch (e) {
      // Emit error to trigger listener
      emit(ManpowerError(e.toString()));
      
      // Restore previous loaded state so UI doesn't crash/show loading
      if (previousState is ManpowerLoaded) {
        emit(previousState);
      } else {
        // Only if we weren't loaded, try to fetch again or stay in error
        // But usually we are loaded when adding user.
        await fetchAllUsers(); 
      }
    }
  }
}
