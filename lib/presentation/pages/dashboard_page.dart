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

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allow gradient to go behind AppBar
      drawer: const Drawer(child: Sidebar()),
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
            onPressed: () => context.read<DashboardCubit>().loadData(force: true),
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
        child: SafeArea( // Rest of the tree remains the same
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
    );
  }

  Widget _buildGlassPanel({required Widget child, EdgeInsetsGeometry? padding}) {
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
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, $name', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$nrp - $position', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
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
                     // Theme for date picker needs to be handled via Theme or Builder if Dark
                   );
                   if (picked != null) context.read<DashboardCubit>().updateFilter(date: picked);
                },
                child: _buildGlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd MMM yyyy').format(state.selectedDate), style: const TextStyle(fontSize: 14, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Less vertical for dropdown
                  child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.selectedShift,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF004e92), // Match/Complement Gradient
                    icon: const Icon(Icons.expand_more, color: Colors.white),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Shift 1 (06-18)")),
                      DropdownMenuItem(value: 2, child: Text("Shift 2 (18-06)")),
                    ],
                    onChanged: (val) {
                      if (val != null) context.read<DashboardCubit>().updateFilter(shift: val);
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
              _periodButton(context, 'Week', DashboardPeriod.week, state.selectedPeriod),
              const SizedBox(width: 4),
              _periodButton(context, 'Month', DashboardPeriod.month, state.selectedPeriod),
            ],
          ),
        );
      },
    );
  }

  Widget _periodButton(BuildContext context, String label, DashboardPeriod value, DashboardPeriod groupValue) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => context.read<DashboardCubit>().updateFilter(period: value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
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
        for (var item in state.shift1Data) spots1.add(FlSpot(item['day'].toDouble(), item['count'].toDouble()));
        for (var item in state.shift2Data) spots2.add(FlSpot(item['day'].toDouble(), item['count'].toDouble()));

        // X-Axis Titles Logic
        Widget bottomTitles(double value, TitleMeta meta) {
          const style = TextStyle(fontSize: 10, color: Colors.white70); // Light Text
          String text;
          if (state.selectedPeriod == DashboardPeriod.week) {
             const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
             int idx = value.toInt() - 1;
             if (idx >= 0 && idx < 7) text = days[idx];
             else text = '';
          } else {
             if (value % 5 == 0) text = value.toInt().toString();
             else text = '';
          }
          return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
        }

        return _buildGlassPanel(
          child: SizedBox( // Sized Box for Height consistency
            height: 380,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOTO Achievement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text('${val.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.white70)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: bottomTitles)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          touchedSpots.sort((a, b) => a.barIndex.compareTo(b.barIndex));
                          return touchedSpots.asMap().entries.map((entry) {
                            final index = entry.key;
                            final spot = entry.value;
                            final shift = spot.barIndex == 0 ? 'Shift 1' : 'Shift 2';
                            final val = spot.y.toInt();

                            DateTime date;
                            if (state.selectedPeriod == DashboardPeriod.week) {
                              final current = state.selectedDate; // This needs to be captured from context/state
                              final monday = current.subtract(Duration(days: current.weekday - 1));
                              date = monday.add(Duration(days: spot.x.toInt() - 1));
                            } else {
                              date = DateTime(state.selectedDate.year, state.selectedDate.month, spot.x.toInt());
                            }
                            final dateStr = DateFormat('dd/MM/yy').format(date);
                            
                            String text;
                            if (index == 0) {
                              text = 'Tanggal : $dateStr\n$shift : $val%';
                            } else {
                              text = '$shift : $val%';
                            }
                            return LineTooltipItem(
                              text,
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            );
                          }).toList();
                        },
                        tooltipBgColor: Colors.black.withOpacity(0.8), // Dark Tooltip
                      ),
                    ),
                    lineBarsData: [
                      // Shift 1 (Blue/Cyan Gradient)
                      LineChartBarData(
                        spots: spots1,
                        isCurved: true,
                        gradient: const LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]), // Cyan-Blue
                        barWidth: 2, // Thinner
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF4facfe),
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [const Color(0xFF4facfe).withOpacity(0.3), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Shift 2 (Orange/Gold Gradient)
                      LineChartBarData(
                        spots: spots2,
                        isCurved: true,
                        gradient: const LinearGradient(colors: [Color(0xFFfa709a), Color(0xFFfee140)]), // Pink-Gold
                        barWidth: 2, // Thinner
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFFfa709a),
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [const Color(0xFFfa709a).withOpacity(0.3), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _buildLegendItem(const Color(0xFF4facfe), 'Shift 1'), // Cyan-Blue Match
                   const SizedBox(width: 16),
                   _buildLegendItem(const Color(0xFFfa709a), 'Shift 2'), // Pink-Gold Match
                ],
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)])),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
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
              const Text('LOTO By Warehouse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            ),
                            FractionallySizedBox(
                              widthFactor: value / 100, // 0..1
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  // Gradient bar (Green/Teal for Warehouse)
                                  gradient: const LinearGradient(colors: [Colors.greenAccent, Colors.tealAccent]),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 6)]
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text('${value.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.end),
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
              const Text('Achievement By NRP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            ),
                            FractionallySizedBox(
                              widthFactor: value / 100, // 0..1
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  // Gradient bar
                                  gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurpleAccent]),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 6)]
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text('${value.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.end),
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
        padding: const EdgeInsets.all(8), // Padding inside glass handled by _buildGlassPanel logic above? No, nested.
        // Actually _buildGlassPanel applies 16 padding by default.
        child: Column(
          children: const [
            Icon(Icons.health_and_safety, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text('Fit To Work Achievement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Text('Coming Soon', style: TextStyle(fontSize: 14, color: Colors.white38, fontStyle: FontStyle.italic)),
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
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
