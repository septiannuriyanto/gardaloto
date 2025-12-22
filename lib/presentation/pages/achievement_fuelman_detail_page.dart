import 'package:fl_chart/fl_chart.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_cubit.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_state.dart';
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
          (context) => FuelmanDetailCubit(
            lotoRepo: sl<LotoRepository>(),
            nrp: widget.nrp,
          )..loadDailyAchievement(),
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildChartSection(),
                  const SizedBox(height: 24),
                  Expanded(child: _buildReconciliationSection()),
                ],
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
          final now = DateTime.now();
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
        final now = DateTime.now();
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
          return const Center(child: CircularProgressIndicator());
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
            Expanded(
              child:
                  filteredList.isEmpty
                      ? Center(
                        child: Text(
                          'No matching records found',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildReconciliationCard(item);
                        },
                      ),
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

  Widget _buildReconciliationCard(Map<String, dynamic> item) {
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
    );
  }
}
