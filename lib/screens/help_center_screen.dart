import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Yardım Merkezi',
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBox(),
          const SizedBox(height: 24),
          _buildSectionHeader('Sıkça Sorulan Sorular'),
          _buildFaqItem(
            'Profilimi nasıl güncellerim?',
            'Ayarlar > Kişisel Bilgiler sayfasından veya Profil ekranınızdaki düzenle butonundan profilinizi güncelleyebilirsiniz.',
          ),
          _buildFaqItem(
            'Takım nasıl oluşturulur?',
            'Ana ekrandaki "Takım Oluştur" butonuna basarak yeni bir takım kurabilir ve üye arayabilirsiniz.',
          ),
          _buildFaqItem(
            'Hesabımı nasıl silebilirim?',
            'Ayarlar > Oturum Açma ve Güvenlik sayfasının en altında bulunan "Hesabı Kapat" seçeneği ile işleminizi gerçekleştirebilirsiniz.',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Bize Ulaşın'),
          _buildContactItem(
            icon: Icons.email_outlined,
            title: 'E-posta Gönder',
            subtitle: 'support@talentmesh.com',
            onTap: () => _launchUrl('mailto:support@talentmesh.com'),
          ),
          _buildContactItem(
            icon: Icons.language_outlined,
            title: 'Web Sitemizi Ziyaret Edin',
            subtitle: 'www.talentmesh.com',
            onTap: () => _launchUrl('https://www.talentmesh.com'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Nasıl yardımcı olabiliriz?',
          hintStyle: GoogleFonts.inter(color: AppColors.mutedText),
          prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.headingText,
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.bodyText,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            answer,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.mutedText,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryAccent),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.headingText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.mutedText,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.mutedText),
      onTap: onTap,
    );
  }
}
