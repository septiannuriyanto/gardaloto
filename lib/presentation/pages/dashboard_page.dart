import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
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
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/pages/achievement_fuelman_detail_page.dart';
import 'package:gardaloto/presentation/cubit/fuelman_detail_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(sl<LotoRepository>())..loadData(),
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

  void _viewPhoto(String url) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: PhotoView(
                imageProvider: CachedNetworkImageProvider(url),
                heroAttributes: const PhotoViewHeroAttributes(
                  tag: 'dashboard_avatar_view',
                ),
              ),
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
        String? photoUrl;

        if (state is AuthAuthenticated) {
          name = state.user.nama ?? 'User';
          nrp = state.user.nrp!;
          // Use description if available
          position =
              state.user.positionDescription ??
              'Position ${state.user.position}';
          photoUrl = state.user.photoUrl;
        }
        return _buildGlassPanel(
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    _viewPhoto(photoUrl);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: ClipOval(
                      child:
                          photoUrl != null && photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                placeholder:
                                    (context, url) =>
                                        Container(color: Colors.white10),
                                errorWidget:
                                    (context, url, error) => const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                              )
                              : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome,',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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

  Widget _buildSelectors(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Row(
          children: [
            // Period Switcher (Replaces Date Picker)
            Expanded(
              child: _buildGlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _periodButton(
                        context,
                        'Week',
                        DashboardPeriod.week,
                        state.selectedPeriod,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _periodButton(
                        context,
                        'Month',
                        DashboardPeriod.month,
                        state.selectedPeriod,
                      ),
                    ),
                  ],
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
                child: SizedBox(
                  height: 36, // Match Period Button Height
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: state.selectedShift,
                      isExpanded: true,
                      isDense: true, // Compact
                      dropdownColor: const Color(0xFF004e92),
                      icon: const Icon(Icons.expand_more, color: Colors.white),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ), // Match font size
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
                          context.read<DashboardCubit>().updateFilter(
                            shift: val,
                          );
                      },
                    ),
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
        height: 36, // Explicit Height
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ), // Remove vertical padding as we use alignment/height
        alignment: Alignment.center,
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
            fontSize: 12,
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
        final double mainWidth = 2.0; // Even Thinner (User request)
        final double subWidth = isAll ? 1.5 : 2.0;
        final double subOpacity = isAll ? 0.5 : 1.0;

        // Trend (Avg)
        if (showAvg) {
          bars.add(
            LineChartBarData(
              spots: spotsAvg,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
              ),
              barWidth: mainWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: _showDotOnlyOnAvg,
                getDotPainter:
                    (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3, // Smaller
                      color: const Color(0xFF4facfe),
                      strokeWidth: 1.0,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: !isAll,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4facfe).withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          );
        }

        // Shift 1 - Amber to Pink Gradient (User Request)
        if (showS1) {
          bars.add(
            LineChartBarData(
              spots: spots1,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFFfee140), Color(0xFFfa709a)], // Amber -> Pink
              ),
              barWidth: subWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter:
                    (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3,
                      color: const Color(
                        0xFFFF3D00,
                      ), // Red-Orange (User request "merah semi orange")
                      strokeWidth: 1.0,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: !showAvg && !showS2,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFfee140).withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          );
        }

        // Shift 2 - Green to Yellow Gradient (User Request)
        if (showS2) {
          bars.add(
            LineChartBarData(
              spots: spots2,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00E676),
                  Color(0xFFFFEA00),
                ], // Green -> Yellow
              ),
              barWidth: subWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter:
                    (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3,
                      color: const Color(
                        0xFF00E676,
                      ), // Bright Green (User request "hijau terang")
                      strokeWidth: 1.0,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: !showAvg && !showS1,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E676).withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          );
        }

        // Horizontal Scrolling Logic
        final isScrollable = state.selectedPeriod == DashboardPeriod.month;
        double chartWidth =
            MediaQuery.of(context).size.width -
            64 -
            40; // Subtract padding & Y-Axis width
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOTO Achievement Trend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      _buildLastVerificationText(
                        context,
                        state.lastVerificationCode,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                  if (showAvg)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Trend',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Chart Container
              SizedBox(
                height: 300,
                child: Row(
                  children: [
                    // Frozen Y-Axis
                    SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children:
                            [100, 80, 60, 40, 20, 0]
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 0),
                                    child: Text(
                                      '$e%',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    // Scrollable Chart Area
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller:
                            isScrollable ? _chartScrollController : null,
                        physics:
                            isScrollable
                                ? const BouncingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: chartWidth,
                          child: LineChart(
                            LineChartData(
                              // ... grid & titles ...
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingVerticalLine:
                                    (_) => FlLine(
                                      color: Colors.white.withOpacity(0.05),
                                      strokeWidth: 1,
                                    ),
                                getDrawingHorizontalLine:
                                    (_) => FlLine(
                                      color: Colors.white.withOpacity(0.1),
                                      strokeWidth: 1,
                                    ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize:
                                        32, // Ensure space for "dd MMM"
                                    interval: 1,
                                    getTitlesWidget:
                                        (val, meta) =>
                                            _bottomTitles(val, meta, state),
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              // ... touch data ...
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  fitInsideVertically: true,
                                  fitInsideHorizontally: true,
                                  getTooltipItems: (touchedSpots) {
                                    touchedSpots.sort(
                                      (a, b) =>
                                          a.barIndex.compareTo(b.barIndex),
                                    );
                                    return touchedSpots.map((spot) {
                                      final val = spot.y.toInt();
                                      String label = '';
                                      int relativeIndex = spot.barIndex;
                                      if (showAvg) {
                                        if (relativeIndex == 0)
                                          label = 'Trend';
                                        else if (showS1 && relativeIndex == 1)
                                          label = 'Shift 1';
                                        else
                                          label = 'Shift 2';
                                        if (showAvg &&
                                            !showS1 &&
                                            relativeIndex == 1)
                                          label = 'Shift 2';
                                      } else {
                                        if (showS1 && relativeIndex == 0)
                                          label = 'Shift 1';
                                        else
                                          label = 'Shift 2';
                                      }

                                      return LineTooltipItem(
                                        '$label: $val%',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    }).toList();
                                  },
                                  tooltipBgColor: Colors.black.withOpacity(0.8),
                                ),
                              ),
                              lineBarsData: bars,
                              minY: 0,
                              maxY: 100,
                              minX: 0.5,
                              maxX: state.shift1Data.length.toDouble() + 0.5,
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
                    const SizedBox(width: 16),
                  ],
                  if (showS1) ...[
                    _buildLegendItem(const Color(0xFFFF3D00), 'Shift 1'),
                    const SizedBox(width: 16),
                  ],
                  if (showS2) ...[
                    _buildLegendItem(const Color(0xFF00E676), 'Shift 2'),
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
    if (value % 1 != 0) return const SizedBox.shrink();

    const style = TextStyle(fontSize: 10, color: Colors.white70);
    String text = '';
    int idx = value.toInt() - 1;

    if (idx >= 0 && idx < state.shift1Data.length) {
      final item = state.shift1Data[idx];
      if (item['date'] is DateTime) {
        text = DateFormat('dd').format(item['date']);
      }
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
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  bool _isOutdated(int? code) {
    if (code == null) return true; // No data = Outdated
    final s = code.toString();
    if (s.length < 10) return true;

    try {
      final yy = int.parse(s.substring(0, 2));
      final mm = int.parse(s.substring(2, 4));
      final dd = int.parse(s.substring(4, 6));
      final shift = int.parse(s.substring(6));

      final year = 2000 + yy;
      final date = DateTime(year, mm, dd);

      final nowUtc = DateTime.now().toUtc();
      final nowWita = nowUtc.add(const Duration(hours: 8));

      int getShiftIndex(DateTime d, int s) {
        final dayStart = DateTime(d.year, d.month, d.day);
        final days = dayStart.difference(DateTime(2000)).inDays;
        return (days * 2) + (s - 1);
      }

      int currentShiftNum = (nowWita.hour >= 6 && nowWita.hour < 18) ? 1 : 2;
      DateTime effectiveDate = nowWita;
      if (nowWita.hour < 6) {
        effectiveDate = nowWita.subtract(const Duration(days: 1));
        currentShiftNum = 2;
      }

      final currentShiftIndex = getShiftIndex(effectiveDate, currentShiftNum);
      final dataShiftIndex = getShiftIndex(date, shift);

      final diff = currentShiftIndex - dataShiftIndex;

      return diff > 2;
    } catch (e) {
      return true;
    }
  }

  Widget _buildLastVerificationText(BuildContext context, int? code) {
    if (code == null) return const SizedBox.shrink();

    // Code Format: YYMMDDSSSS (e.g., 2512190002)
    final s = code.toString();
    if (s.length < 10) return const SizedBox.shrink();

    try {
      final yy = int.parse(s.substring(0, 2));
      final mm = int.parse(s.substring(2, 4));
      final dd = int.parse(s.substring(4, 6));
      final shift = int.parse(s.substring(6));

      // Year is likely 20YY
      // final year = 2000 + yy; // Unused
      // final date = DateTime(year, mm, dd); // Unused
      final formattedDate =
          '${dd.toString().padLeft(2, '0')}/${mm.toString().padLeft(2, '0')}/$yy';

      final label = 'Last Verification Data : $formattedDate shift $shift';
      final isOutdated = _isOutdated(code);

      // Logic: > 2 shift diff -> Red
      // <= 2 shift diff -> Light Blue (Achievement Trend Color)

      Color color;
      if (isOutdated) {
        color = Colors.redAccent;
      } else {
        color = const Color(0xFF4facfe); // Light Blue
      }

      return Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
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
              if (_isOutdated(state.lastVerificationCode)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    "Data Verifikasi Belum Update",
                    style: TextStyle(color: Colors.redAccent, fontSize: 10),
                  ),
                ),
              ],
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
                'Achievement by Fuelman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_isOutdated(state.lastVerificationCode)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    "Data Verifikasi Belum Update",
                    style: TextStyle(color: Colors.redAccent, fontSize: 10),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ...state.nrpData.asMap().entries.map((entry) {
                final item = entry.value;
                final label = item['label'];
                final value = (item['value'] as num).toDouble();
                final displayValue = '${value.toInt()}%';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () {
                      final nrp = item['nrp'];
                      if (nrp != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => BlocProvider(
                                  create:
                                      (context) => FuelmanDetailCubit(
                                        lotoRepo: sl<LotoRepository>(),
                                        nrp: nrp,
                                      )..loadDailyAchievement(),
                                  child: AchievementFuelmanDetailPage(
                                    nrp: nrp,
                                    name: label,
                                  ),
                                ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot view details: NRP is missing',
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Name & Value
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              displayValue,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress Bar
                        Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (value / 100).clamp(0.0, 1.0),
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.purpleAccent,
                                      Colors.deepPurpleAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
