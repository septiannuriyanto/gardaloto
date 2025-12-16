import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';
import 'package:gardaloto/domain/repositories/storage_repository.dart';

abstract class StorageState extends Equatable {
  const StorageState();
  @override
  List<Object?> get props => [];
}

class StorageInitial extends StorageState {}

class StorageSyncing extends StorageState {}

class StorageSynced extends StorageState {
  final String message;
  final List<StorageEntity> warehouses;

  const StorageSynced(this.message, this.warehouses);

  @override
  List<Object?> get props => [message, warehouses];
}

class StorageError extends StorageState {
  final String message;
  const StorageError(this.message);
  @override
  List<Object?> get props => [message];
}

class StorageCubit extends Cubit<StorageState> {
  final StorageRepository repo;

  StorageCubit(this.repo) : super(StorageInitial());

  Future<void> syncAndLoad() async {
    emit(StorageSyncing());
    try {
      final msg = await repo.syncStorage();
      final warehouses = await repo.getWarehouses();
      emit(StorageSynced(msg, warehouses));
    } catch (e) {
      // Even if sync fails, try to load local data
      try {
        final warehouses = await repo.getWarehouses();
        if (warehouses.isNotEmpty) {
           emit(StorageSynced('Sync failed: $e. Using local data.', warehouses));
           return;
        }
      } catch (_) {}
      
      emit(StorageError(e.toString()));
    }
  }
  Future<void> loadLocalOnly() async {
    try {
      final warehouses = await repo.getWarehouses();
      emit(StorageSynced('Loaded local data', warehouses));
    } catch (e) {
      emit(StorageError(e.toString()));
    }
  }
}
