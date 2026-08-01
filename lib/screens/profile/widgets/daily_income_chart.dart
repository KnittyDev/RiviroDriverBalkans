import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DailyIncomeChart extends StatelessWidget {
  const DailyIncomeChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Hourly data: label, ratio (0.0 - 1.0), isLow
    final data = [
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
          const Text(
            'Daily income',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              // Grid Y-Axis Lines and Labels
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1000€',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Text(
                      '500€',
                      style: TextStyle(
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
                              ? const Color(0xFFF87171).withOpacity(0.8) // soft red
                              : AppColors.primary; // brand #99CFCF

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 9,
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
                        return SizedBox(
                          width: 9,
                          child: Text(
                            item.hour,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 8.5,
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
}

class _ChartBarData {
  final String hour;
  final double ratio;
  final bool isLow;

  _ChartBarData(this.hour, this.ratio, {this.isLow = false});
}
