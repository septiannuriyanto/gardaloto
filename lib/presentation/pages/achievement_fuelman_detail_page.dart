import 'package:fl_chart/fl_chart.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_cubit.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_state.dart';
import 'package:gardaloto/core/time_helper.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/widget/capture_form_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AchievementFuelmanDetailPage extends StatefulWidget {
  final String nrp;
  final String name;

  const AchievementFuelmanDetailPage({
    super.key,
    required this.nrp,
    required this.name,
  });

  @override
  State<AchievementFuelmanDetailPage> createState() =>
      _AchievementFuelmanDetailPageState();
}

class _AchievementFuelmanDetailPageState
    extends State<AchievementFuelmanDetailPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final screenWidth = MediaQuery.of(context).size.width;
        // Viewport width = Screen - (Horizontal Padding of Page: 32) - (Horizontal Padding of Container: 32)
        final viewportWidth = screenWidth - 64;
        const itemWidth = 45.0;

        // Target: Align the right edge of the bar at `index` to the right edge of viewport.
        // Right edge of bar `index` = (index + 1) * itemWidth.
        final targetX = (index + 1) * itemWidth;

        // We add a little extra padding (16) so it's not flush against the edge
        double offset = targetX - viewportWidth + 16;

        if (offset < 0) offset = 0;
        if (offset > _scrollController.position.maxScrollExtent) {
          offset = _scrollController.position.maxScrollExtent;
        }

        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              FuelmanDetailCubit(
                  lotoRepo: sl<LotoRepository>(),
                  nrp: widget.nrp,
                )
                ..loadDailyAchievement()
                ..loadMonthlyRecords(),
      child: BlocListener<FuelmanDetailCubit, FuelmanDetailState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'LOTO Achievement detail by Fuelman',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027), // Deep Dark Blue/Black
                  Color(0xFF203A43), // Muted Teal/Grey-Blue
                  Color(0xFF2C5364), // Softer Blue-Grey
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildChartSection(),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 300,
                        child: _buildRecordHistorySection(),
                      ),
                      const SizedBox(height: 24),
                      _buildReconciliationSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF4facfe),
            child: Text(
              widget.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.nrp,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return BlocConsumer<FuelmanDetailCubit, FuelmanDetailState>(
      listenWhen: (prev, curr) => prev.isLoading != curr.isLoading,
      listener: (context, state) {
        if (!state.isLoading && state.dailyAchievement.isNotEmpty) {
          // Find the index of the latest data point
          final now = TimeHelper.now();
          final startOfMonth = DateTime(now.year, now.month, 1);

          DateTime? maxDate;
          for (var item in state.dailyAchievement) {
            final dStr = item['date'] as String;
            final d = DateTime.parse(dStr);
            if (maxDate == null || d.isAfter(maxDate)) {
              maxDate = d;
            }
          }

          if (maxDate != null) {
            // Calculate index: Difference in days from startOfMonth
            // e.g. Start=1st, Max=5th -> Index 4 (0,1,2,3,4)
            final diff = maxDate.difference(startOfMonth).inDays;
            _scrollToIndex(diff);
          }
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Generate Dates for Current Month (1st to End)
        final now = TimeHelper.now();
        // Use 1st day of current month
        final startOfMonth = DateTime(now.year, now.month, 1);
        // Use last day of current month
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final daysInMonth = <DateTime>[];
        for (
          var d = startOfMonth;
          d.isBefore(endOfMonth) || d.isAtSameMomentAs(endOfMonth);
          d = d.add(const Duration(days: 1))
        ) {
          daysInMonth.add(d);
        }

        // Map data for fast lookup: "YYYY-MM-DD" -> { shift: { percentage, ... } }
        final dataMap = <String, Map<int, Map<String, dynamic>>>{};
        for (var item in state.dailyAchievement) {
          final dateStr = item['date'] as String; // "YYYY-MM-DD"
          final shift = item['shift'] as int;
          // ignore: prefer_collection_literals
          if (!dataMap.containsKey(dateStr)) dataMap[dateStr] = {};
          dataMap[dateStr]![shift] = item;
        }

        final barGroups = <BarChartGroupData>[];

        for (int i = 0; i < daysInMonth.length; i++) {
          final date = daysInMonth[i];
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final dayData = dataMap[dateStr] ?? {};

          // Shift 1
          final s1Item = dayData[1];
          final s1Val =
              s1Item != null ? (s1Item['percentage'] as num).toDouble() : 0.0;
          final s1Selected =
              state.selectedDate != null &&
              DateFormat('yyyy-MM-dd').format(state.selectedDate!) == dateStr &&
              state.selectedShift == 1;

          // Shift 2
          final s2Item = dayData[2];
          final s2Val =
              s2Item != null ? (s2Item['percentage'] as num).toDouble() : 0.0;
          final s2Selected =
              state.selectedDate != null &&
              DateFormat('yyyy-MM-dd').format(state.selectedDate!) == dateStr &&
              state.selectedShift == 2;

          barGroups.add(
            BarChartGroupData(
              x: i,
              barsSpace: 4, // Space between S1 and S2 rods
              barRods: [
                // Shift 1 Rod
                BarChartRodData(
                  toY: s1Val,
                  color:
                      s1Selected
                          ? Colors.white
                          : const Color(0xFF4facfe), // Blue
                  width: 10,
                  borderRadius: BorderRadius.circular(2),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                // Shift 2 Rod
                BarChartRodData(
                  toY: s2Val,
                  color:
                      s2Selected
                          ? Colors.white
                          : const Color(0xFF00bcd4), // Cyan/Teal
                  width: 10,
                  borderRadius: BorderRadius.circular(2),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate scroll width
        // 35-40px per group (10+10 rods + 4 space + padding)
        final chartWidth = daysInMonth.length * 45.0;

        return Container(
          height: 200, // Reduced height by ~50%
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Performance (Current Month)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _scrollController,
                  child: Container(
                    width:
                        chartWidth < MediaQuery.of(context).size.width - 64
                            ? MediaQuery.of(context).size.width -
                                64 // Min width matches screen
                            : chartWidth,
                    padding: const EdgeInsets.only(right: 16),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceEvenly,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.white.withValues(alpha: 0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 30,
                              getTitlesWidget: (val, meta) {
                                int idx = val.toInt();
                                if (idx >= 0 && idx < daysInMonth.length) {
                                  final date = daysInMonth[idx];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('dd').format(date),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: 100,
                        barGroups: barGroups,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final idx = group.x.toInt();
                              if (idx >= 0 && idx < daysInMonth.length) {
                                final date = daysInMonth[idx];
                                final dateFmt = NumberFormat(
                                  "00",
                                ).format(date.day);
                                // rodIndex 0 = Shift 1, 1 = Shift 2
                                final shift = rodIndex + 1;
                                final val = rod.toY;
                                return BarTooltipItem(
                                  '$dateFmt (Shift $shift)\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${val.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: rod.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return null;
                            },
                          ),
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent &&
                                response != null &&
                                response.spot != null) {
                              final idx = response.spot!.touchedBarGroupIndex;
                              final rodIdx = response.spot!.touchedRodDataIndex;

                              if (idx >= 0 && idx < daysInMonth.length) {
                                final date = daysInMonth[idx];
                                final shift = rodIdx + 1; // 0->1, 1->2

                                context.read<FuelmanDetailCubit>().selectPoint(
                                  date,
                                  shift,
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF4facfe),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Shift 1',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF00bcd4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Shift 2',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReconciliationSection() {
    return BlocBuilder<FuelmanDetailCubit, FuelmanDetailState>(
      builder: (context, state) {
        if (state.selectedDate == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap on the chart to view reconciliation details',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          );
        }

        if (state.isReconciliationLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final dateStr = DateFormat('dd MMM yyyy').format(state.selectedDate!);

        // Calculate counts
        int verifiedCount = 0;
        int unplannedCount = 0;
        int missingCount = 0;

        for (var item in state.reconciliationData) {
          final status = item['status'];
          if (status == 'MATCH') verifiedCount++;
          if (status == 'EXTRA_LOTO') unplannedCount++;
          if (status == 'MISSING_LOTO') missingCount++;
        }

        final totalCount = state.reconciliationData.length;

        // Find achievement percentage for the selected date/shift
        double achievement = 0;
        final selectedDateStr =
            state.selectedDate?.toIso8601String().split('T')[0];

        if (selectedDateStr != null) {
          final found = state.dailyAchievement.firstWhere(
            (element) =>
                element['date'] == selectedDateStr &&
                element['shift'] == state.selectedShift,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            achievement = (found['percentage'] as num).toDouble();
          }
        }

        // Filter the list based on selection
        final filteredList =
            state.selectedFilterStatus == null
                ? state.reconciliationData
                : state.reconciliationData
                    .where(
                      (item) => item['status'] == state.selectedFilterStatus,
                    )
                    .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTED DATE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'SHIFT',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.selectedShift.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ACHIEVEMENT',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${achievement.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color:
                                  achievement >= 85
                                      ? Colors.greenAccent
                                      : (achievement >= 70
                                          ? Colors.orangeAccent
                                          : Colors.redAccent),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildSummaryCircle(
                          'Total',
                          totalCount,
                          Colors.white,
                          state.selectedFilterStatus == null,
                          () => context
                              .read<FuelmanDetailCubit>()
                              .toggleReconciliationFilter('TOTAL'),
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryCircle(
                          'Verified',
                          verifiedCount,
                          Colors.greenAccent,
                          state.selectedFilterStatus == 'MATCH',
                          () => context
                              .read<FuelmanDetailCubit>()
                              .toggleReconciliationFilter('MATCH'),
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryCircle(
                          'Unplanned',
                          unplannedCount,
                          Colors.orangeAccent,
                          state.selectedFilterStatus == 'EXTRA_LOTO',
                          () => context
                              .read<FuelmanDetailCubit>()
                              .toggleReconciliationFilter('EXTRA_LOTO'),
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryCircle(
                          'Missing',
                          missingCount,
                          Colors.redAccent,
                          state.selectedFilterStatus == 'MISSING_LOTO',
                          () => context
                              .read<FuelmanDetailCubit>()
                              .toggleReconciliationFilter('MISSING_LOTO'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            filteredList.isEmpty
                ? const Center(
                  child: Text(
                    'No matching records found',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildReconciliationCard(context, item);
                  },
                ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCircle(
    String label,
    int count,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.2) : null,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isSelected ? 3 : 2),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordHistorySection() {
    return BlocBuilder<FuelmanDetailCubit, FuelmanDetailState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record History (Current Month)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    state.isMonthlyRecordsLoading
                        ? _buildHistorySkeleton()
                        : state.monthlyRecords.isEmpty
                        ? const Center(
                          child: Text(
                            'No records found for this month.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                        : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'No',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Date',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Time',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Shift',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Unit',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Session',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                              rows:
                                  state.monthlyRecords.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final record = entry.value;
                                    final timestamp =
                                        record['timestamp_taken'] != null
                                            ? DateTime.parse(
                                              record['timestamp_taken'],
                                            )
                                            : null;
                                    final dateStr =
                                        timestamp != null
                                            ? DateFormat(
                                              'dd MMM',
                                            ).format(timestamp)
                                            : '-';
                                    final timeStr =
                                        timestamp != null
                                            ? DateFormat(
                                              'HH:mm',
                                            ).format(timestamp)
                                            : '-';

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${record['create_shift'] ?? '-'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            record['code_number'] ?? '-',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            record['session_id'] ?? '-',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistorySkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 40,
          color: Colors.white.withValues(alpha: 0.05),
        );
      },
    );
  }

  Widget _buildReconciliationCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final unitCode = item['unit_code'] ?? 'Unknown';
    final status = item['status'] ?? 'UNKNOWN';
    final lotoTimeStr = item['loto_time'];
    final verifyTimeStr = item['verification_time'];

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'MATCH':
        statusColor = Colors.greenAccent;
        statusText = 'Verified & Refueled';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'MISSING_LOTO':
        statusColor = Colors.redAccent;
        statusText = 'Missing LOTO Record';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'EXTRA_LOTO':
        statusColor = Colors.orangeAccent;
        statusText = 'Unplanned Refueling';
        statusIcon = Icons.add_circle_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.help_outline;
    }

    String formatTime(dynamic isoStr) {
      if (isoStr == null) return '-';
      try {
        final dt = DateTime.parse(isoStr.toString()).toLocal();
        return DateFormat('HH:mm').format(dt);
      } catch (e) {
        return '-';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: InkWell(
        onTap:
            status == 'MISSING_LOTO'
                ? () => _handleMissingItemTap(context, item)
                : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unitCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status != 'MISSING_LOTO')
                  Text(
                    'LOTO: ${formatTime(lotoTimeStr)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                if (status != 'EXTRA_LOTO')
                  Text(
                    'Plan: ${formatTime(verifyTimeStr)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMissingItemTap(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final state = context.read<FuelmanDetailCubit>().state;
        final unplannedItems =
            state.reconciliationData
                .where((i) => i['status'] == 'EXTRA_LOTO')
                .toList();
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F2027).withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Resolve Missing LOTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionTile(
                  icon: Icons.sync,
                  label: 'Sync with Unplanned Data',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSyncDialog(context, item, unplannedItems);
                  },
                ),
                const SizedBox(height: 16),
                _buildActionTile(
                  icon: Icons.add_a_photo,
                  label: 'Add Image',
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToAddImage(context, item);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDialog(
    BuildContext context,
    Map<String, dynamic> missingItem,
    List<Map<String, dynamic>> unplannedItems,
  ) {
    // Capture state for debug
    final state = context.read<FuelmanDetailCubit>().state;
    final matchCount =
        state.reconciliationData.where((e) => e['status'] == 'MATCH').length;
    final missingCount =
        state.reconciliationData
            .where((e) => e['status'] == 'MISSING_LOTO')
            .length;
    final extraCount =
        state.reconciliationData
            .where((e) => e['status'] == 'EXTRA_LOTO')
            .length;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return _SyncDialog(
          missingItem: missingItem,
          unplannedItems: unplannedItems,
          state: state,
          matchCount: matchCount,
          missingCount: missingCount,
          extraCount: extraCount,
          cubit: context.read<FuelmanDetailCubit>(),
        );
      },
    );
  }

  Future<void> _navigateToAddImage(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final picker = ImagePicker();
    final XFile? image = await showDialog<XFile?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder:
          (ctx) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              title: const Text(
                "Add Image Source",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt,
                      color: Colors.cyanAccent,
                    ),
                    title: const Text(
                      "Camera",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(
                        ctx,
                        await picker.pickImage(source: ImageSource.camera),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.purpleAccent,
                    ),
                    title: const Text(
                      "Gallery",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(
                        ctx,
                        await picker.pickImage(source: ImageSource.gallery),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );

    if (image == null) return;
    if (!context.mounted) return;

    final sessionCode = item['session_code'];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => BlocProvider(
              create: (ctx) {
                final cubit = LotoCubit(sl<LotoRepository>());

                cubit.setSession(
                  LotoSession(
                    nomor: sessionCode ?? 'UNKNOWN',
                    dateTime: TimeHelper.now(),
                    shift: 1,
                    warehouseCode: 'UNKNOWN',
                    fuelman: 'UNKNOWN',
                    operatorName: 'UNKNOWN',
                  ),
                );

                cubit.startCapture(photoPath: image.path);
                cubit.setCaptureSelectedCode(item['unit_code']);
                return cubit;
              },
              child: const CaptureFormPage(),
            ),
      ),
    );

    if (context.mounted) {
      final cubit = context.read<FuelmanDetailCubit>();
      if (cubit.state.selectedDate != null &&
          cubit.state.selectedShift != null) {
        cubit.selectPoint(
          cubit.state.selectedDate!,
          cubit.state.selectedShift!,
        );
      }
    }
  }
}

class _SyncDialog extends StatefulWidget {
  final Map<String, dynamic> missingItem;
  final List<Map<String, dynamic>> unplannedItems;
  final FuelmanDetailState state;
  final int matchCount;
  final int missingCount;
  final int extraCount;
  final FuelmanDetailCubit cubit;

  const _SyncDialog({
    required this.missingItem,
    required this.unplannedItems,
    required this.state,
    required this.matchCount,
    required this.missingCount,
    required this.extraCount,
    required this.cubit,
  });

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  String? selectedRecordId;
  String? selectedUnitCode;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Sync with Unplanned Data",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.unplannedItems.isEmpty) ...[
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orangeAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Unplanned items available to sync.\n\nDebug Info:\nTotal: ${widget.state.reconciliationData.length}\nMATCH: ${widget.matchCount}\nMISSING: ${widget.missingCount}\nEXTRA: ${widget.extraCount}",
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "MISSING UNIT",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.missingItem['unit_code'] ?? 'UNKNOWN',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Select an Unplanned (Extra) LOTO record to assign to this missing unit:",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: widget.unplannedItems.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = widget.unplannedItems[index];
                              // Ensure robust comparison by converting to string if needed
                              // Handle potential key mismatch from RPC (record_id vs rid)
                              final itemId =
                                  (item['record_id'] ?? item['rid'])
                                      ?.toString();
                              final isSelected =
                                  itemId != null && selectedRecordId == itemId;

                              return Material(
                                color: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.green.withValues(
                                              alpha: 0.3,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? Colors.green
                                              : Colors.white10,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        selectedRecordId = itemId;
                                        selectedUnitCode = item['unit_code'];
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color:
                                                isSelected
                                                    ? Colors.green
                                                    : Colors.white54,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['unit_code'] ?? '-',
                                                  style: TextStyle(
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : Colors.white70,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.unplannedItems.isNotEmpty)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          disabledBackgroundColor: Colors.white10,
                        ),
                        onPressed:
                            selectedRecordId == null
                                ? null
                                : () {
                                  Navigator.of(context).pop();
                                  widget.cubit.resolveMissingWithUnplanned(
                                    selectedRecordId!,
                                    widget.missingItem['unit_code'],
                                  );
                                },
                        child: const Text(
                          "Sync",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
