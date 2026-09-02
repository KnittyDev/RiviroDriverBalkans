import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/driver_stats_service.dart';
import '../../../theme/app_theme.dart';

enum IncomeTimeframe { daily, weekly, monthly }

class DailyIncomeChart extends StatefulWidget {
  const DailyIncomeChart({super.key});

  @override
  State<DailyIncomeChart> createState() => _DailyIncomeChartState();
}

class _DailyIncomeChartState extends State<DailyIncomeChart> {
  IncomeTimeframe _selectedTimeframe = IncomeTimeframe.daily;

  List<_ChartBarData> _getChartData(DriverStatsModel stats) {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        final hours = ['09', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20'];
        double maxHourly = 0.0;
        for (final h in hours) {
          final val = stats.hourlyEarningsToday[h] ?? stats.hourlyEarningsToday['$h:00'] ?? 0.0;
          if (val > maxHourly) maxHourly = val;
        }

        return hours.map((h) {
          final val = stats.hourlyEarningsToday[h] ?? stats.hourlyEarningsToday['$h:00'] ?? 0.0;
          final ratio = maxHourly > 0 ? (val / maxHourly).clamp(0.1, 1.0) : 0.15;
          final isLow = maxHourly > 0 ? (val / maxHourly) < 0.25 : false;
          return _ChartBarData(h, ratio, isLow: isLow);
        }).toList();

      case IncomeTimeframe.weekly:
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        double maxDay = 0.0;
        for (final d in days) {
          final val = stats.weeklyDayEarnings[d] ?? 0.0;
          if (val > maxDay) maxDay = val;
        }

        return days.map((d) {
          final val = stats.weeklyDayEarnings[d] ?? 0.0;
          final ratio = maxDay > 0 ? (val / maxDay).clamp(0.1, 1.0) : 0.2;
          final isLow = maxDay > 0 ? (val / maxDay) < 0.25 : false;
          return _ChartBarData(d, ratio, isLow: isLow);
        }).toList();

      case IncomeTimeframe.monthly:
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        double maxMonth = 0.0;
        for (final m in months) {
          final val = stats.monthlyEarnings[m] ?? 0.0;
          if (val > maxMonth) maxMonth = val;
        }

        return months.map((m) {
          final val = stats.monthlyEarnings[m] ?? 0.0;
          final ratio = maxMonth > 0 ? (val / maxMonth).clamp(0.1, 1.0) : 0.2;
          final isLow = maxMonth > 0 ? (val / maxMonth) < 0.25 : false;
          return _ChartBarData(m, ratio, isLow: isLow);
        }).toList();
    }
  }

  String _getTotalIncome(DriverStatsModel stats) {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        return stats.formatCurrency(stats.earningsToday);
      case IncomeTimeframe.weekly:
        double weekSum = 0.0;
        for (final v in stats.weeklyDayEarnings.values) {
          weekSum += v;
        }
        if (weekSum <= 0 && stats.earningsToday > 0) {
          weekSum = stats.earningsToday;
        }
        return stats.formatCurrency(weekSum);
      case IncomeTimeframe.monthly:
        double monthSum = 0.0;
        for (final v in stats.monthlyEarnings.values) {
          monthSum += v;
        }
        if (monthSum <= 0) {
          monthSum = stats.earningsToday > 0 ? stats.earningsToday : stats.totalBalance.clamp(0.0, 999999.0);
        }
        return stats.formatCurrency(monthSum);
    }
  }

  String _getYMaxLabel(DriverStatsModel stats) {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        final max = (stats.earningsToday > 0 ? stats.earningsToday * 1.4 : 100.0).clamp(50.0, 1000.0);
        return stats.formatCurrency(max.toInt());
      case IncomeTimeframe.weekly:
        return stats.formatCurrency(500);
      case IncomeTimeframe.monthly:
        return stats.formatCurrency(2000);
    }
  }

  String _getYMidLabel(DriverStatsModel stats) {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        final mid = (stats.earningsToday > 0 ? stats.earningsToday * 0.7 : 50.0).clamp(25.0, 500.0);
        return stats.formatCurrency(mid.toInt());
      case IncomeTimeframe.weekly:
        return stats.formatCurrency(250);
      case IncomeTimeframe.monthly:
        return stats.formatCurrency(1000);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverStatsModel>(
      valueListenable: DriverStatsService.statsNotifier,
      builder: (context, stats, child) {
        final data = _getChartData(stats);
        final totalIncomeStr = _getTotalIncome(stats);
        final yMaxStr = _getYMaxLabel(stats);
        final yMidStr = _getYMidLabel(stats);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Title + Amount Column and Timeframe Selector Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earnings',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        totalIncomeStr,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                  // Timeframe Segmented Control
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _buildTimeframeTab('Daily', IncomeTimeframe.daily),
                        _buildTimeframeTab('Weekly', IncomeTimeframe.weekly),
                        _buildTimeframeTab('Monthly', IncomeTimeframe.monthly),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chart Section
              Stack(
                children: [
                  // Grid Y-Axis Lines and Labels
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          yMaxStr,
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          yMidStr,
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14), // space for x-axis
                      ],
                    ),
                  ),
                  // Bar chart content
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 65,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: data.map((item) {
                              final color = item.isLow
                                  ? const Color(0xFFF87171) // soft red
                                  : AppColors.primary; // brand #99CFCF

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: data.length > 7 ? 8 : 18,
                                    height: (60 * item.ratio).clamp(6.0, 60.0),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // X-axis labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: data.map((item) {
                            return Expanded(
                              child: Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: GoogleFonts.poppins(
                                  fontSize: data.length > 7 ? 8 : 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeframeTab(String label, IncomeTimeframe timeframe) {
    final isSelected = _selectedTimeframe == timeframe;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeframe = timeframe;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _ChartBarData {
  final String label;
  final double ratio;
  final bool isLow;

  _ChartBarData(this.label, this.ratio, {this.isLow = false});
}
