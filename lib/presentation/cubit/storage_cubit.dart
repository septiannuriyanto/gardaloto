import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';
import 'package:gardaloto/domain/repositories/storage_repository.dart';
import 'package:gardaloto/core/utils/network_utils.dart';

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
    // 1. Pre-check connection
    final hasInternet = await NetworkUtils.hasInternetConnection();
    if (!hasInternet) {
       await loadLocalOnly();
       if (state is StorageSynced) {
         final current = state as StorageSynced;
         emit(StorageSynced("Offline Mode. Using local data.", current.warehouses));
       }
       return;
    }

    emit(StorageSyncing());
    try {
      final msg = await repo.syncStorage();
      final warehouses = await repo.getWarehouses();
      emit(StorageSynced(msg, warehouses));
    } catch (e) {
      // If sync fails, try to load local data
      try {
        final warehouses = await repo.getWarehouses();
        if (warehouses.isNotEmpty) {
           final msg = e.toString();
           final userMsg = (msg.contains("SocketException") || msg.contains("AuthRetryableFetchException")) 
               ? "Offline mode" 
               : "Sync failed. Using local data.";
           emit(StorageSynced(userMsg, warehouses));
           return;
        }
      } catch (_) {}
      
      final msg = e.toString();
      if (msg.contains("SocketException") || msg.contains("AuthRetryableFetchException")) {
         emit(const StorageError("Network Error. Showing available options."));
      } else {
         emit(StorageError("Error: $msg"));
      }
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
