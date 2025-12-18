import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:gardaloto/presentation/cubit/dashboard_cubit.dart';
import 'package:gardaloto/presentation/cubit/dashboard_state.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit()..loadData(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final ScrollController _chartScrollController = ScrollController();

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  // Scroll to end when switching to month or initially
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.jumpTo(
          _chartScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen:
          (previous, current) =>
              previous.selectedPeriod != current.selectedPeriod ||
              previous.isLoading != current.isLoading,
      listener: (context, state) {
        if (!state.isLoading && state.selectedPeriod == DashboardPeriod.month) {
          _scrollToEnd();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true, // Allow gradient to go behind AppBar
        drawer: const Sidebar(),
        appBar: AppBar(
          title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent, // Glass AppBar
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.blue.shade900.withOpacity(0.2)),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed:
                  () => context.read<DashboardCubit>().loadData(force: true),
            ),
          ],
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
            // Rest of the tree remains the same
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildSelectors(context),
                  const SizedBox(height: 24),

                  // Universal Period Switcher (Glass Style)
                  _buildPeriodSwitcher(context),
                  const SizedBox(height: 16),

                  // Charts
                  _buildLotoChart(context),
                  const SizedBox(height: 24),
                  _buildWarehouseChart(context),
                  const SizedBox(height: 24),
                  _buildNrpChart(context),
                  const SizedBox(height: 24),

                  _buildFitToWorkPanel(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Frosted Glass
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Translucent
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        String name = 'User';
        String nrp = '-';
        String position = '-';
        if (state is AuthAuthenticated) {
          name = state.user.nama ?? 'User';
          nrp = state.user.nrp!;
          position = 'Position ${state.user.position}';
        }
        // Header can be a distinct Glass Panel or just "Floating" text
        // Let's make it a nice Glass Card
        return _buildGlassPanel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$nrp - $position',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Need to update Text colors inside charts to WHITE if background is DARK
  // Since I chose a Dark Gradient (Navy/Blue), text MUST be white.

  Widget _buildSelectors(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  // Date Picker
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null)
                    context.read<DashboardCubit>().updateFilter(date: picked);
                },
                child: _buildGlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(state.selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.selectedShift,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF004e92),
                    icon: const Icon(Icons.expand_more, color: Colors.white),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text("Trend (Default)"),
                      ),
                      DropdownMenuItem(value: 1, child: Text("Shift 1 Only")),
                      DropdownMenuItem(value: 2, child: Text("Shift 2 Only")),
                      DropdownMenuItem(value: 3, child: Text("All Series")),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        context.read<DashboardCubit>().updateFilter(shift: val);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ... (Period Switcher Unchanged) ...
  Widget _buildPeriodSwitcher(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Darker track
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _periodButton(
                context,
                'Week',
                DashboardPeriod.week,
                state.selectedPeriod,
              ),
              const SizedBox(width: 4),
              _periodButton(
                context,
                'Month',
                DashboardPeriod.month,
                state.selectedPeriod,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _periodButton(
    BuildContext context,
    String label,
    DashboardPeriod value,
    DashboardPeriod groupValue,
  ) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => context.read<DashboardCubit>().updateFilter(period: value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLotoChart(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.isLoading) return _buildSkeleton(380);

        List<FlSpot> spots1 = [];
        List<FlSpot> spots2 = [];
        List<FlSpot> spotsAvg = [];

        // Parse Data
        for (var item in state.shift1Data) {
          spots1.add(FlSpot(item['day'].toDouble(), item['count'].toDouble()));
        }
        for (var item in state.shift2Data) {
          spots2.add(FlSpot(item['day'].toDouble(), item['count'].toDouble()));
        }

        // Calculate Average always (needed for Trend and All)
        final maxLen = spots1.length;
        for (int i = 0; i < maxLen; i++) {
          if (i < spots2.length) {
            final s1 = spots1[i];
            final s2 = spots2[i];
            final avg = (s1.y + s2.y) / 2;
            spotsAvg.add(FlSpot(s1.x, avg));
          }
        }

        List<LineChartBarData> bars = [];
        
        // Mode: 0=Trend, 1=S1, 2=S2, 3=All
        final showS1 = state.selectedShift == 1 || state.selectedShift == 3;
        final showS2 = state.selectedShift == 2 || state.selectedShift == 3;
        final showAvg = state.selectedShift == 0 || state.selectedShift == 3;

        // Visual Config
        final isAll = state.selectedShift == 3;
        final double mainWidth = 4;
        final double subWidth = isAll ? 1.5 : 4;
        final double subOpacity = isAll ? 0.5 : 1.0;

        // Trend (Avg) - Now Primary Blue Gradient
        if (showAvg) {
            bars.add(LineChartBarData(
              spots: spotsAvg, 
              isCurved: true, 
              gradient: const LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]), // Cyan-Blue
              barWidth: mainWidth, 
              isStrokeCapRound: true, 
              dotData: FlDotData(show: true, checkToShowDot: _showDotOnlyOnAvg), 
              belowBarData: BarAreaData(
                show: !isAll, // Only fill if isolated (Trend only)
                gradient: LinearGradient(colors: [const Color(0xFF4facfe).withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              ),
            ));
        }

        // Shift 1 - Now Amber/Pink Gradient
        if (showS1) {
           bars.add(LineChartBarData(
              spots: spots1, isCurved: true,
              gradient: LinearGradient(
                colors: [const Color(0xFFfa709a).withOpacity(subOpacity), const Color(0xFFfee140).withOpacity(subOpacity)]
              ), // Pink-Gold (Amber-ish)
              barWidth: subWidth, 
              isStrokeCapRound: true, 
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: !showAvg && !showS2, // Only show fill if isolated S1
                gradient: LinearGradient(colors: [const Color(0xFFfa709a).withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              ),
           ));
        }
        
        // Shift 2 - Now Purple/Magenta
        if (showS2) {
           bars.add(LineChartBarData(
              spots: spots2, isCurved: true,
              gradient: LinearGradient(
                colors: [const Color(0xFFD500F9).withOpacity(subOpacity), const Color(0xFF8E2DE2).withOpacity(subOpacity)] // Magenta Accent -> Deep Purple
              ), 
              barWidth: subWidth, 
              isStrokeCapRound: true, 
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: !showAvg && !showS1, // Only show fill if isolated S2
                gradient: LinearGradient(colors: [const Color(0xFFD500F9).withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              ),
           ));
        }

        // Horizontal Scrolling Logic
        final isScrollable = state.selectedPeriod == DashboardPeriod.month;
        double chartWidth = MediaQuery.of(context).size.width - 64 - 40; // Subtract padding & Y-Axis width
        if (isScrollable) {
          final days = state.shift1Data.length;
          chartWidth = days * 40.0;
        }

        return _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('LOTO Achievement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (showAvg)
                     // Trend using Blue Gradient colors for text/icon indication?
                     Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]))),
                        const SizedBox(width: 4),
                        const Text('Trend', style: TextStyle(fontSize: 10, color: Colors.white70)),
                     ]),
                ],
              ),
              const SizedBox(height: 24),
              // ... Chart Container ...
              SizedBox(
                 height: 300,
                 child: Row(
                   children: [
                     // Frozen Y-Axis
                     SizedBox(
                       width: 40,
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [100, 80, 60, 40, 20, 0].map((e) => 
                           Padding(
                             padding: const EdgeInsets.only(bottom: 0),
                             child: Text('$e%', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                           )
                         ).toList(),
                       ),
                     ),
                     // Scrollable Chart Area
                     Expanded(
                       child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: isScrollable ? _chartScrollController : null,
                          physics: isScrollable ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: chartWidth,
                            child: LineChart(
                              LineChartData(
                                // ... grid & titles ...
                                gridData: FlGridData(
                                   show: true, 
                                   drawVerticalLine: true, 
                                   getDrawingVerticalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                                   getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1)
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (val, meta) => _bottomTitles(val, meta, state))),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                // ... touch data ...
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    fitInsideVertically: true,
                                    fitInsideHorizontally: true,
                                    getTooltipItems: (touchedSpots) {
                                       touchedSpots.sort((a, b) => a.barIndex.compareTo(b.barIndex));
                                       return touchedSpots.map((spot) {
                                          final val = spot.y.toInt();
                                          String label = '';
                                          // Identify series based on insertion order and show flags
                                          // Order: Avg (if show), S1 (if show), S2 (if show)
                                          // Actually, insertion order matters.
                                          // My code adds: Avg (0), S1 (1), S2 (2) if all shown.
                                          // If Avg hidden: S1 (0), S2 (1).
                                          // This dynamic index is tricky.
                                          // Let's rely on Color to match or just Generic Labels if hard.
                                          // Easier: Map barIndex to specific series if we know the order we added them.
                                          // We added: Avg -> S1 -> S2.
                                          // So if showAvg is true, Index 0 is Trend.
                                          // If showAvg false, Index 0 is S1.
                                          
                                          int relativeIndex = spot.barIndex;
                                          if (showAvg) {
                                            if (relativeIndex == 0) label = 'Trend';
                                            else if (showS1 && relativeIndex == 1) label = 'Shift 1';
                                            else label = 'Shift 2'; // Roughly correct given the combinations
                                            // Edge case: ShowAvg + ShowS2 (no S1). Index 1 is S2.
                                            if (showAvg && !showS1 && relativeIndex == 1) label = 'Shift 2';
                                          } else {
                                            if (showS1 && relativeIndex == 0) label = 'Shift 1';
                                            else label = 'Shift 2';
                                          }
                                          
                                          return LineTooltipItem(
                                            '$label: $val%', 
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                                          );
                                       }).toList();
                                    },
                                    tooltipBgColor: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                lineBarsData: bars,
                                minY: 0,
                                maxY: 100,
                              ),
                            ),
                          ),
                       ),
                     ),
                   ],
                 ),
              ),
              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   if (showAvg) ...[
                      _buildLegendItem(const Color(0xFF4facfe), 'Trend'), 
                      const SizedBox(width: 16)
                   ],
                   if (showS1) ...[
                      _buildLegendItem(const Color(0xFFfa709a), 'Shift 1'), 
                      const SizedBox(width: 16)
                   ],
                   if (showS2) ...[
                      _buildLegendItem(const Color(0xFFD500F9), 'Shift 2'), 
                   ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _showDotOnlyOnAvg(FlSpot spot, LineChartBarData barData) {
    return true;
  }

  Widget _bottomTitles(double value, TitleMeta meta, DashboardState state) {
    const style = TextStyle(fontSize: 10, color: Colors.white70);
    String text = '';
    if (state.selectedPeriod == DashboardPeriod.week) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      int idx = value.toInt() - 1;
      if (idx >= 0 && idx < 7) text = days[idx];
    } else {
      if (value % 2 == 0 || value % 2 == 1) text = value.toInt().toString();
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseChart(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.isLoading) return _buildSkeleton(300);

        return _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOTO By Warehouse',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...state.warehouseData.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final label = item['label'];
                final value = (item['value'] as num).toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: value / 100, // 0..1
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  // Gradient bar (Green/Teal for Warehouse)
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.greenAccent,
                                      Colors.tealAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.greenAccent.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNrpChart(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.isLoading) return _buildSkeleton(300);

        return _buildGlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Achievement By NRP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...state.nrpData.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final label = item['label'];
                final value = (item['value'] as num).toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: value / 100, // 0..1
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  // Gradient bar
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.purpleAccent,
                                      Colors.deepPurpleAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purpleAccent.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFitToWorkPanel(BuildContext context) {
    return _buildGlassPanel(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(
          8,
        ), // Padding inside glass handled by _buildGlassPanel logic above? No, nested.
        // Actually _buildGlassPanel applies 16 padding by default.
        child: Column(
          children: const [
            Icon(Icons.health_and_safety, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Fit To Work Achievement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white38,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(double height) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
