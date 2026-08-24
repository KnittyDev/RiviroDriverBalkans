import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class RiderContactModal extends StatelessWidget {
  final String passengerName;
  final String passengerRating;
  final String phoneNumber;

  const RiderContactModal({
    super.key,
    this.passengerName = 'Sophia M.',
    this.passengerRating = '4.9',
    this.phoneNumber = '+48 512 345 678',
  });

  static void show(
    BuildContext context, {
    String passengerName = 'Sophia M.',
    String passengerRating = '4.9',
    String phoneNumber = '+48 512 345 678',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RiderContactModal(
        passengerName: passengerName,
        passengerRating: passengerRating,
        phoneNumber: phoneNumber,
      ),
    );
  }

  String get _cleanPhoneNumber => phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Phone number $phoneNumber copied to clipboard!',
          style: GoogleFonts.poppins(fontSize: 12.5),
        ),
        backgroundColor: AppColors.textDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAppNotInstalledDialog(
    BuildContext context, {
    required String appName,
    required String iconAsset,
    required String webUrlFallback,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                iconAsset,
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$appName Not Installed',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$appName app is not installed on your phone. Would you like to copy $passengerName\'s phone number ($phoneNumber) to your clipboard?',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _copyToClipboard(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.copy_rounded, color: AppColors.textDark, size: 16),
            label: Text(
              'Copy Number',
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchCellularCall(BuildContext context) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    try {
      final launched = await launchUrl(url);
      if (!launched && context.mounted) {
        _copyToClipboard(context);
      }
    } catch (_) {
      if (context.mounted) {
        _copyToClipboard(context);
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final Uri appUri = Uri.parse('whatsapp://send?phone=$_cleanPhoneNumber');
    final Uri webUri = Uri.parse('https://wa.me/$_cleanPhoneNumber');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          _showAppNotInstalledDialog(
            context,
            appName: 'WhatsApp',
            iconAsset: 'assets/whatshapp.svg',
            webUrlFallback: 'https://wa.me/$_cleanPhoneNumber',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          _showAppNotInstalledDialog(
            context,
            appName: 'WhatsApp',
            iconAsset: 'assets/whatshapp.svg',
            webUrlFallback: 'https://wa.me/$_cleanPhoneNumber',
          );
        }
      }
    }
  }

  Future<void> _launchViber(BuildContext context) async {
    final Uri appUri = Uri.parse('viber://chat?number=%2B$_cleanPhoneNumber');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          _showAppNotInstalledDialog(
            context,
            appName: 'Viber',
            iconAsset: 'assets/viber.svg',
            webUrlFallback: '',
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        _showAppNotInstalledDialog(
          context,
          appName: 'Viber',
          iconAsset: 'assets/viber.svg',
          webUrlFallback: '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: safeBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Passenger Info Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySubtle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: const ClipOval(
                  child: Icon(
                    Icons.person_rounded,
                    size: 34,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$passengerRating • Active Passenger',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            'Choose Contact Method',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // 1. Direct Phone Call
          _buildOptionTile(
            title: 'Cellular Phone Call',
            subtitle: 'Direct phone call via mobile carrier',
            iconWidget: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
            ),
            onTap: () {
              Navigator.pop(context);
              _launchCellularCall(context);
            },
          ),
          const SizedBox(height: 10),

          // 2. WhatsApp
          _buildOptionTile(
            title: 'WhatsApp Chat / Call',
            subtitle: 'Message or call via WhatsApp',
            iconWidget: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/whatshapp.svg',
                width: 24,
                height: 24,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _launchWhatsApp(context);
            },
          ),
          const SizedBox(height: 10),

          // 3. Viber
          _buildOptionTile(
            title: 'Viber Call / Message',
            subtitle: 'Free call or message via Viber',
            iconWidget: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7360F2).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/viber.svg',
                width: 24,
                height: 24,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _launchViber(context);
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: iconWidget,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
