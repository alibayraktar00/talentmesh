import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  void _showUnderDevelopment(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature özelliği yakında eklenecek!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Oturum Açma ve Güvenlik',
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
          _buildSectionHeader('Hesap Erişimi'),
          _buildSecurityItem(
            title: 'E-posta Adresi',
            value: 'kullanici@example.com', // Dinamik veri eklenebilir
            onTap: () => _showUnderDevelopment('E-posta Güncelleme'),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSecurityItem(
            title: 'Telefon Numarası',
            value: 'Eklenmedi',
            onTap: () => _showUnderDevelopment('Telefon Ekleme'),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSecurityItem(
            title: 'Şifreyi Değiştir',
            value: 'En son 3 ay önce değiştirildi',
            onTap: () => _showUnderDevelopment('Şifre Değiştirme'),
          ),
          
          _buildSectionHeader('Ek Güvenlik'),
          _buildSecurityItem(
            title: 'İki Faktörlü Kimlik Doğrulama',
            value: 'Kapalı',
            onTap: () => _showUnderDevelopment('2FA'),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSecurityItem(
            title: 'Cihaz Yönetimi',
            value: 'Şu an aktif olan 1 cihaz',
            onTap: () => _showUnderDevelopment('Cihaz Yönetimi'),
          ),

          const SizedBox(height: 32),
          _buildDangerZone(),
          const SizedBox(height: 40),
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

  Widget _buildSecurityItem({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesap Yönetimi',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showUnderDevelopment('Hesabı Kapat'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Hesabı Kapat',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
