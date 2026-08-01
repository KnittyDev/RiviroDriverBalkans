import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

enum IncomeTimeframe { daily, weekly, monthly }

class DailyIncomeChart extends StatefulWidget {
  const DailyIncomeChart({super.key});

  @override
  State<DailyIncomeChart> createState() => _DailyIncomeChartState();
}

class _DailyIncomeChartState extends State<DailyIncomeChart> {
  IncomeTimeframe _selectedTimeframe = IncomeTimeframe.daily;

  List<_ChartBarData> get _currentData {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        return [
          _ChartBarData('09', 0.25, isLow: true),
          _ChartBarData('10', 0.45),
          _ChartBarData('11', 0.35),
          _ChartBarData('12', 0.75),
          _ChartBarData('13', 0.60),
          _ChartBarData('14', 0.85),
          _ChartBarData('15', 0.50),
          _ChartBarData('16', 0.55),
          _ChartBarData('17', 0.20, isLow: true),
          _ChartBarData('18', 0.30, isLow: true),
          _ChartBarData('19', 0.80),
          _ChartBarData('20', 0.50),
        ];
      case IncomeTimeframe.weekly:
        return [
          _ChartBarData('Mon', 0.50),
          _ChartBarData('Tue', 0.65),
          _ChartBarData('Wed', 0.40, isLow: true),
          _ChartBarData('Thu', 0.75),
          _ChartBarData('Fri', 0.95),
          _ChartBarData('Sat', 0.90),
          _ChartBarData('Sun', 0.60),
        ];
      case IncomeTimeframe.monthly:
        return [
          _ChartBarData('Jan', 0.55),
          _ChartBarData('Feb', 0.60),
          _ChartBarData('Mar', 0.70),
          _ChartBarData('Apr', 0.65),
          _ChartBarData('May', 0.80),
          _ChartBarData('Jun', 0.85),
          _ChartBarData('Jul', 0.90),
          _ChartBarData('Aug', 0.75),
          _ChartBarData('Sep', 0.65),
          _ChartBarData('Oct', 0.70),
          _ChartBarData('Nov', 0.85),
          _ChartBarData('Dec', 0.95),
        ];
    }
  }

  String get _totalIncome {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        return '124.50€';
      case IncomeTimeframe.weekly:
        return '842.00€';
      case IncomeTimeframe.monthly:
        return '3,450.00€';
    }
  }

  String get _yMaxLabel {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        return '1000€';
      case IncomeTimeframe.weekly:
        return '1500€';
      case IncomeTimeframe.monthly:
        return '5000€';
    }
  }

  String get _yMidLabel {
    switch (_selectedTimeframe) {
      case IncomeTimeframe.daily:
        return '500€';
      case IncomeTimeframe.weekly:
        return '750€';
      case IncomeTimeframe.monthly:
        return '2500€';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

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
                    _totalIncome,
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
                      _yMaxLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      _yMidLabel,
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
                                height: 60 * item.ratio,
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
