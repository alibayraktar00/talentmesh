import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class VisibilitySettingsScreen extends StatefulWidget {
  const VisibilitySettingsScreen({super.key});

  @override
  State<VisibilitySettingsScreen> createState() => _VisibilitySettingsScreenState();
}

class _VisibilitySettingsScreenState extends State<VisibilitySettingsScreen> {
  bool _isProfilePublic = true;
  bool _showActiveStatus = true;
  bool _showEmail = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Görünürlük',
          style: GoogleFonts.inter(
            color: AppColors.headingText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.headingText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Profil Görünürlüğü'),
          _buildSwitchItem(
            title: 'Profilimi Herkese Aç',
            description: 'Kapalıyken profilinizi sadece arkadaşlarınız görebilir.',
            value: _isProfilePublic,
            onChanged: (val) => setState(() => _isProfilePublic = val),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          
          _buildSectionHeader('Durum Bilgisi'),
          _buildSwitchItem(
            title: 'Aktiflik Durumu',
            description: 'Çevrimiçi olduğunuzda arkadaşlarınızın bunu görmesine izin verin.',
            value: _showActiveStatus,
            onChanged: (val) => setState(() => _showActiveStatus = val),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),

          _buildSectionHeader('İletişim Bilgileri'),
          _buildSwitchItem(
            title: 'E-posta Adresini Göster',
            description: 'E-posta adresinizin profilinizde görünmesini sağlar.',
            value: _showEmail,
            onChanged: (val) => setState(() => _showEmail = val),
          ),
          
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bu ayarlar TalentMesh üzerindeki deneyiminizi nasıl yönettiğinizi belirler. Değişiklikler anında uygulanır.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryAccent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryAccent,
          ),
        ],
      ),
    );
  }
}
