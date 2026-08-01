import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safeBottomInset = MediaQuery.of(context).padding.bottom + 30;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms of Service',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: safeBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EU Flag & Regulation Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🇪🇺',
                          style: TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EU Regulation Compliant',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fully aligned with EU Transport Directive 2024/1284 & European Union Driver Protection Standard.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textDark.withOpacity(0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Article 1
              _buildSectionTitle('1. Driver Eligibility & Licensing'),
              _buildParagraph(
                'Drivers operating under the Rivilo platform within European Union member states must hold a valid EU/EEA Category B driver license with a minimum of 2 years driving experience. Vehicles must satisfy local EU technical inspection regulations.',
              ),
              const SizedBox(height: 18),

              // Article 2
              _buildSectionTitle('2. Platform Service Fee & Payouts'),
              _buildParagraph(
                'Rivilo applies a transparent platform service fee on all completed passenger rides. Payouts are executed via SEPA Instant transfers directly into your registered EU bank IBAN according to local financial compliance laws.',
              ),
              const SizedBox(height: 18),

              // Article 3
              _buildSectionTitle('3. Real-Time GPS Tracking & Safety'),
              _buildParagraph(
                'For passenger and driver safety, live GPS location coordinates are processed during online status and active trip navigation. Emergency SOS assistance integrates directly with European Emergency Number 112 services.',
              ),
              const SizedBox(height: 18),

              // Article 4
              _buildSectionTitle('4. Conduct & Equal Opportunity'),
              _buildParagraph(
                'Rivilo strictly strictly enforces non-discrimination policies in accordance with Article 21 of the EU Charter of Fundamental Rights. Zero tolerance is maintained for harassment or non-compliance.',
              ),
              const SizedBox(height: 30),

              // Footer Note
              Center(
                child: Text(
                  'Last Updated: January 2026 • Rivilo Europe B.V.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          color: AppColors.textMuted,
          height: 1.55,
        ),
      ),
    );
  }
}
