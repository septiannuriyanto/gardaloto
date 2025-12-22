import 'package:equatable/equatable.dart';

class FuelmanDetailState extends Equatable {
  final bool isLoading;
  final bool isReconciliationLoading;
  final String? errorMessage;

  // Daily Achievement Chart Data
  final List<Map<String, dynamic>> dailyAchievement;

  // Selected Data Point for Reconciliation
  final DateTime? selectedDate;
  final int? selectedShift;

  // Reconciliation List
  final List<Map<String, dynamic>> reconciliationData;

  // Filter for Reconciliation List (null = All)
  final String? selectedFilterStatus;

  const FuelmanDetailState({
    this.isLoading = false,
    this.isReconciliationLoading = false,
    this.errorMessage,
    this.dailyAchievement = const [],
    this.selectedDate,
    this.selectedShift,
    this.reconciliationData = const [],
    this.selectedFilterStatus,
  });

  FuelmanDetailState copyWith({
    bool? isLoading,
    bool? isReconciliationLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? dailyAchievement,
    DateTime? selectedDate,
    int? selectedShift,
    List<Map<String, dynamic>>? reconciliationData,
    String? selectedFilterStatus,
    bool forceClearFilter = false,
  }) {
    return FuelmanDetailState(
      isLoading: isLoading ?? this.isLoading,
      isReconciliationLoading:
          isReconciliationLoading ?? this.isReconciliationLoading,
      errorMessage: errorMessage,
      dailyAchievement: dailyAchievement ?? this.dailyAchievement,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedShift: selectedShift ?? this.selectedShift,
      reconciliationData: reconciliationData ?? this.reconciliationData,
      selectedFilterStatus:
          forceClearFilter
              ? null
              : (selectedFilterStatus ?? this.selectedFilterStatus),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isReconciliationLoading,
    errorMessage,
    dailyAchievement,
    selectedDate,
    selectedShift,
    reconciliationData,
    selectedFilterStatus,
  ];
}
