import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DriverGrowthBoostModal extends StatefulWidget {
  const DriverGrowthBoostModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DriverGrowthBoostModal(),
    );
  }

  @override
  State<DriverGrowthBoostModal> createState() => _DriverGrowthBoostModalState();
}

class _DriverGrowthBoostModalState extends State<DriverGrowthBoostModal> {
  int _selectedFilter = 0; // 0: All, 1: Top, 2: Amenities

  static const List<Map<String, dynamic>> _boostTips = [
    {
      'title': 'Chargers & Water',
      'category': 'Amenities',
      'boost': '+200% Tips',
      'accentColor': Color(0xFF3B82F6),
      'icon': Icons.power_rounded,
      'isHighPriority': true,
      'isAmenity': true,
      'description':
          'Equip multi-head USB-C and Lightning phone chargers in rear seats and provide free bottled water. Extra comfort leads to 2x more 5-star ratings and higher tips.',
    },
    {
      'title': 'High Rating (4.9+)',
      'category': 'Ratings',
      'boost': '+50% Match',
      'accentColor': Color(0xFFF59E0B),
      'icon': Icons.star_rounded,
      'isHighPriority': true,
      'isAmenity': false,
      'description':
          'Maintain a rating of 4.9 or higher. Top-rated drivers receive first access to high-fare rides, airport transfers, and corporate requests.',
    },
    {
      'title': 'Peak Hours & Active',
      'category': 'Dispatch',
      'boost': '+40% Speed',
      'accentColor': Color(0xFF10B981),
      'icon': Icons.bolt_rounded,
      'isHighPriority': true,
      'isAmenity': false,
      'description':
          'Stay online during morning rush hours (07:00–10:00) and evening peak hours (17:00–21:00). High acceptance rate guarantees priority dispatch.',
    },
    {
      'title': 'Clean Interior',
      'category': 'Maintenance',
      'boost': '+35% Rating',
      'accentColor': Color(0xFF8B5CF6),
      'icon': Icons.auto_awesome_rounded,
      'isHighPriority': false,
      'isAmenity': true,
      'description':
          'Keep vehicle interior vacuumed and fresh. A clean cabin creates an instant positive impression and prevents low rating feedback.',
    },
    {
      'title': 'Pickup Radius',
      'category': 'Location',
      'boost': '+30% Coverage',
      'accentColor': Color(0xFFEC4899),
      'icon': Icons.location_on_rounded,
      'isHighPriority': false,
      'isAmenity': false,
      'description':
          'Set an optimal pickup range on your Home screen slider (5-15 km). This keeps you in active request zones without driving empty miles.',
    },
    {
      'title': 'Polite & Music',
      'category': 'Experience',
      'boost': '+25% Tips',
      'accentColor': Color(0xFF06B6D4),
      'icon': Icons.music_note_rounded,
      'isHighPriority': false,
      'isAmenity': true,
      'description':
          'Greet passengers politely ("Hello, welcome!"). Play low background music or ask passenger preference for a peaceful journey.',
    },
  ];

  List<Map<String, dynamic>> get _filteredTips {
    if (_selectedFilter == 1) {
      return _boostTips.where((t) => t['isHighPriority'] == true).toList();
    } else if (_selectedFilter == 2) {
      return _boostTips.where((t) => t['isAmenity'] == true).toList();
    }
    return _boostTips;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 12;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.78,
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

          // Header Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver Tips',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Maximize ride requests & earnings',
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
          const SizedBox(height: 12),

          // Segmented Filter Tabs
          Row(
            children: [
              _buildFilterTab(0, 'All'),
              const SizedBox(width: 6),
              _buildFilterTab(1, 'Top Tips'),
              const SizedBox(width: 6),
              _buildFilterTab(2, 'Amenities'),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Tips List
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredTips.length,
              itemBuilder: (context, index) {
                final tip = _filteredTips[index];
                return _buildTipCard(tip);
              },
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              label: Text(
                'Got It',
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

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip) {
    final Color accentColor = tip['accentColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tip['icon'] as IconData,
                  color: accentColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      tip['category'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryActiveBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  tip['boost'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tip['description'] as String,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF475569),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
