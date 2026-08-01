import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
              // EU Flag & GDPR Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF15803D).withOpacity(0.3)),
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
                          'GDPR & EU Data Protection Law',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complies strictly with EU General Data Protection Regulation (GDPR) Regulation (EU) 2016/679.',
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
              _buildSectionTitle('1. Data Sovereignty & EU Storage'),
              _buildParagraph(
                'All driver telemetry, identity documents, and location records are stored strictly within ISO 27001 certified data centers located in Frankfurt, Germany and Warsaw, Poland. Data never leaves the European Economic Area (EEA).',
              ),
              const SizedBox(height: 18),

              // Article 2
              _buildSectionTitle('2. Right to Access & Erasure (GDPR Art. 17)'),
              _buildParagraph(
                'Under GDPR Article 17 ("Right to be Forgotten"), you retain full rights to request a complete export of your personal data or permanent erasure of your account records at any time via privacy@rivilo.eu.',
              ),
              const SizedBox(height: 18),

              // Article 3
              _buildSectionTitle('3. Real-Time Location Privacy'),
              _buildParagraph(
                'GPS location is accessed exclusively when you switch to "Online" status or during active trip navigation. Location tracking automatically ceases the moment you set your status to "Offline".',
              ),
              const SizedBox(height: 18),

              // Article 4
              _buildSectionTitle('4. Encryption & Financial Security'),
              _buildParagraph(
                'Bank IBAN details and document scans are encrypted end-to-end using AES-256 military-grade encryption in transit and at rest in compliance with EU Banking Authority standards.',
              ),
              const SizedBox(height: 30),

              // Footer Note
              Center(
                child: Text(
                  'Data Controller: Rivilo Privacy Office, EU • GDPR Compliant',
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
