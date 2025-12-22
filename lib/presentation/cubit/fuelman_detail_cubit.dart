import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_state.dart';

class FuelmanDetailCubit extends Cubit<FuelmanDetailState> {
  final LotoRepository lotoRepo;
  final String nrp;

  FuelmanDetailCubit({required this.lotoRepo, required this.nrp})
    : super(const FuelmanDetailState());

  Future<void> loadDailyAchievement() async {
    emit(state.copyWith(isLoading: true));
    try {
      // Fetch 30 days back
      final data = await lotoRepo.getFuelmanDailyAchievement(nrp);
      emit(state.copyWith(isLoading: false, dailyAchievement: data));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> selectPoint(DateTime date, int shift) async {
    // If same point selected, do nothing or toggle? Let's just reload.
    if (state.selectedDate == date && state.selectedShift == shift) return;

    emit(
      state.copyWith(
        selectedDate: date,
        selectedShift: shift,
        isReconciliationLoading: true,
        reconciliationData: [], // Clear previous
        forceClearFilter: true, // Reset filter on new date selection
      ),
    );

    try {
      final data = await lotoRepo.getFuelmanReconciliation(nrp, date, shift);
      emit(
        state.copyWith(
          isReconciliationLoading: false,
          reconciliationData: data,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isReconciliationLoading: false,
          errorMessage: "Failed to load reconciliation",
        ),
      );
    }
  }

  void toggleReconciliationFilter(String? status) {
    if (status == null || status == 'TOTAL') {
      emit(state.copyWith(forceClearFilter: true));
      return;
    }

    if (state.selectedFilterStatus == status) {
      // Toggle off if same selected
      emit(state.copyWith(forceClearFilter: true));
    } else {
      emit(state.copyWith(selectedFilterStatus: status));
    }
  }
}
