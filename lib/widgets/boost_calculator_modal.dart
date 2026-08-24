import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BoostCalculatorModal extends StatefulWidget {
  const BoostCalculatorModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BoostCalculatorModal(),
    );
  }

  @override
  State<BoostCalculatorModal> createState() => _BoostCalculatorModalState();
}

class _BoostCalculatorModalState extends State<BoostCalculatorModal> {
  final Set<int> _selectedItems = {1, 2, 3}; // Default selected criteria

  static const List<Map<String, dynamic>> _checklist = [
    {
      'id': 0,
      'title': 'Phone Chargers & Water Amenities',
      'boost': '+80% Boost',
      'points': 40,
      'icon': Icons.power_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'id': 1,
      'title': 'High Driver Rating (4.9+ Stars)',
      'boost': '+40% Boost',
      'points': 20,
      'icon': Icons.star_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 2,
      'title': 'Online During Peak Hours (7-10 AM / 5-9 PM)',
      'boost': '+30% Boost',
      'points': 15,
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'id': 3,
      'title': 'Clean & Vacuumed Interior',
      'boost': '+20% Boost',
      'points': 10,
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'id': 4,
      'title': 'Optimal Service Radius (5-15 km)',
      'boost': '+15% Boost',
      'points': 8,
      'icon': Icons.location_on_rounded,
      'color': Color(0xFFEC4899),
    },
    {
      'id': 5,
      'title': 'Polite Greeting & Music Choice',
      'boost': '+15% Boost',
      'points': 7,
      'icon': Icons.music_note_rounded,
      'color': Color(0xFF06B6D4),
    },
  ];

  int get _totalPoints {
    int score = 0;
    for (final item in _checklist) {
      if (_selectedItems.contains(item['id'])) {
        score += (item['points'] as int);
      }
    }
    return score.clamp(0, 100);
  }

  int get _boostPercentage => (_totalPoints * 2.0).round();

  String get _resultTier {
    final pts = _totalPoints;
    if (pts >= 85) return 'MAX PRO DRIVER';
    if (pts >= 50) return 'OPTIMIZED DRIVER';
    if (pts >= 25) return 'STANDARD DRIVER';
    return 'BASIC DRIVER';
  }

  String get _resultAdvice {
    final pts = _totalPoints;
    if (pts >= 85) {
      return '⭐ Excellent! You receive maximum dispatch priority for premium and high-fare trips.';
    } else if (pts >= 50) {
      return '👍 Good (+${_boostPercentage}% Boost)! Add phone chargers and water amenities to reach MAX 200% boost.';
    } else if (pts >= 25) {
      return '⚡ Fair (+${_boostPercentage}% Boost)! Fulfill 2 more items above to increase ride request frequency.';
    } else {
      return '⚠️ Select the items above that you currently fulfill to test your potential dispatch score.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 12;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calculate Boost Score',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Select what you offer to calculate your score',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Compact Live Score Result Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _resultTier,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4ADE80),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  +$_boostPercentage% Boost',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_totalPoints/100 Pts',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalPoints / 100.0,
                    minHeight: 4.5,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _totalPoints >= 85
                          ? const Color(0xFF22C55E)
                          : (_totalPoints >= 50
                              ? const Color(0xFFF59E0B)
                              : AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Check the items you currently fulfill:',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Checklist
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _checklist.length,
              itemBuilder: (context, index) {
                final item = _checklist[index];
                final int id = item['id'] as int;
                final bool isSelected = _selectedItems.contains(id);
                final Color itemColor = item['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(id);
                      } else {
                        _selectedItems.add(id);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primarySubtle.withOpacity(0.5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: itemColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: itemColor,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_rounded : Icons.add_rounded,
                                size: 12,
                                color: AppColors.textDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                item['boost'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Close Calculation',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
