import 'package:equatable/equatable.dart';

enum DashboardPeriod { week, month }

class DashboardState extends Equatable {
  final DateTime selectedDate;
  final int selectedShift;
  final DashboardPeriod selectedPeriod;
  final bool isLoading;

  final List<Map<String, dynamic>>
  shift1Data; // [{dayOrIndex: 1, count: 5}, ...]
  final List<Map<String, dynamic>> shift2Data;

  // New Charts Data (Categorical)
  final List<Map<String, dynamic>>
  warehouseData; // [{label: 'WH01', value: 85}, ...]
  final List<Map<String, dynamic>>
  nrpData; // [{label: '12345', value: 95}, ...]

  final int? lastVerificationCode; // YYMMDDSSSS

  const DashboardState({
    required this.selectedDate,
    required this.selectedShift,
    this.selectedPeriod = DashboardPeriod.month,
    this.isLoading = false,
    this.shift1Data = const [],
    this.shift2Data = const [],
    this.warehouseData = const [],
    this.nrpData = const [],
    this.lastVerificationCode,
  });

  DashboardState copyWith({
    DateTime? selectedDate,
    int? selectedShift,
    DashboardPeriod? selectedPeriod,
    bool? isLoading,
    List<Map<String, dynamic>>? shift1Data,
    List<Map<String, dynamic>>? shift2Data,
    List<Map<String, dynamic>>? warehouseData,
    List<Map<String, dynamic>>? nrpData,
    int? lastVerificationCode,
  }) {
    return DashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedShift: selectedShift ?? this.selectedShift,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      isLoading: isLoading ?? this.isLoading,
      shift1Data: shift1Data ?? this.shift1Data,
      shift2Data: shift2Data ?? this.shift2Data,
      warehouseData: warehouseData ?? this.warehouseData,
      nrpData: nrpData ?? this.nrpData,
      lastVerificationCode: lastVerificationCode ?? this.lastVerificationCode,
    );
  }

  @override
  List<Object?> get props => [
    selectedDate,
    selectedShift,
    selectedPeriod,
    isLoading,
    shift1Data,
    shift2Data,
    warehouseData,
    nrpData,
    lastVerificationCode,
  ];
}
