import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';

abstract class LotoSessionsState extends Equatable {
  const LotoSessionsState();

  @override
  List<Object?> get props => [];
}

class LotoSessionsInitial extends LotoSessionsState {}

class LotoSessionsLoading extends LotoSessionsState {}

class LotoSessionsLoaded extends LotoSessionsState {
  final List<LotoSession> sessions;
  final DateTime? filterDate;
  final int? filterShift;
  final String? filterWarehouse;
  final String? filterFuelman;
  final String? filterOperator;
  final String filterStatus; // 'All', 'Submitted', 'Pending'
  final Map<String, int> remoteCounts;
  final Map<String, int> localCounts;

  const LotoSessionsLoaded({
    required this.sessions,
    this.filterDate,
    this.filterShift,
    this.filterWarehouse,
    this.filterFuelman,
    this.filterOperator,
    this.filterStatus = 'All',
    this.remoteCounts = const {},
    this.localCounts = const {},
  });

  @override
  List<Object?> get props => [
    sessions,
    filterDate,
    filterShift,
    filterWarehouse,
    filterFuelman,
    filterOperator,
    filterStatus,
    remoteCounts,
    localCounts,
  ];

  LotoSessionsLoaded copyWith({
    List<LotoSession>? sessions,
    DateTime? filterDate,
    int? filterShift,
    String? filterWarehouse,
    String? filterFuelman,
    String? filterOperator,
    String? filterStatus,
    Map<String, int>? remoteCounts,
    Map<String, int>? localCounts,
  }) {
    return LotoSessionsLoaded(
      sessions: sessions ?? this.sessions,
      filterDate: filterDate ?? this.filterDate,
      filterShift: filterShift ?? this.filterShift,
      filterWarehouse: filterWarehouse ?? this.filterWarehouse,
      filterFuelman: filterFuelman ?? this.filterFuelman,
      filterOperator: filterOperator ?? this.filterOperator,
      filterStatus: filterStatus ?? this.filterStatus,
      remoteCounts: remoteCounts ?? this.remoteCounts,
      localCounts: localCounts ?? this.localCounts,
    );
  }
}

class LotoSessionsError extends LotoSessionsState {
  final String message;

  const LotoSessionsError(this.message);

  @override
  List<Object> get props => [message];
}

class LotoSessionsCubit extends Cubit<LotoSessionsState> {
  final LotoRepository _repository;

  LotoSessionsCubit(this._repository) : super(LotoSessionsInitial());

  Future<void> fetchSessions({
    DateTime? date,
    int? shift,
    String? warehouseCode,
    String? fuelman,
    String? operatorName,
    String status = 'All',
  }) async {
    emit(LotoSessionsLoading());
    try {
      final sessions = await _repository.fetchSessions(
        date: date,
        shift: shift,
        warehouseCode: warehouseCode,
        fuelman: fuelman,
        operatorName: operatorName,
      );

      final remoteCounts = <String, int>{};
      final localCounts = <String, int>{};

      for (final session in sessions) {
        remoteCounts[session.nomor] = await _repository.getRemoteRecordCount(session.nomor);
        localCounts[session.nomor] = await _repository.getLocalRecordCount(session.nomor);
      }

      emit(LotoSessionsLoaded(
        sessions: sessions,
        filterDate: date,
        filterShift: shift,
        filterWarehouse: warehouseCode,
        filterFuelman: fuelman,
        filterOperator: operatorName,
        filterStatus: status,
        remoteCounts: remoteCounts,
        localCounts: localCounts,
      ));
    } catch (e) {
      emit(LotoSessionsError(e.toString()));
    }
  }

  Future<void> updateFilters({
    DateTime? date,
    int? shift,
    String? warehouseCode,
    String? fuelman,
    String? operatorName,
    String? status,
  }) async {
    // If state is loaded, preserve other filters if not provided
    DateTime? currentDate;
    int? currentShift;
    String? currentWarehouse;
    String? currentFuelman;
    String? currentOperator;
    String currentStatus = 'All';

    if (state is LotoSessionsLoaded) {
      final loaded = state as LotoSessionsLoaded;
      currentDate = loaded.filterDate;
      currentShift = loaded.filterShift;
      currentWarehouse = loaded.filterWarehouse;
      currentFuelman = loaded.filterFuelman;
      currentOperator = loaded.filterOperator;
      currentStatus = loaded.filterStatus;
    }

    await fetchSessions(
      date: date ?? currentDate,
      shift: shift ?? currentShift,
      warehouseCode: warehouseCode ?? currentWarehouse,
      fuelman: fuelman ?? currentFuelman,
      operatorName: operatorName ?? currentOperator,
      status: status ?? currentStatus,
    );
  }

  void updateSessionCounts(String sessionNomor, int remote, int local) {
    if (state is LotoSessionsLoaded) {
      final currentState = state as LotoSessionsLoaded;
      final newRemoteCounts = Map<String, int>.from(currentState.remoteCounts);
      final newLocalCounts = Map<String, int>.from(currentState.localCounts);

      newRemoteCounts[sessionNomor] = remote;
      newLocalCounts[sessionNomor] = local;

      emit(currentState.copyWith(
        remoteCounts: newRemoteCounts,
        localCounts: newLocalCounts,
      ));
    }
  }
}
