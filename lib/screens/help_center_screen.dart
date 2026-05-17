import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=TalentMesh Destek Talebi',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Yardım Merkezi',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchBox(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Sıkça Sorulan Sorular'),
          _buildFaqItem(
            context,
            'Nasıl takım kurabilirim?',
            'Ana sayfadaki "+" butonuna basarak yeni bir takım oluşturabilir, takımınızın hedeflerini ve aradığınız rolleri belirleyebilirsiniz.',
          ),
          _buildFaqItem(
            context,
            'Takım arkadaşlarımı nasıl bulurum?',
            'Arama kısmından yeteneklere veya isimlere göre arama yapabilir, uygun bulduğunuz kişilere bağlantı isteği gönderebilirsiniz.',
          ),
          _buildFaqItem(
            context,
            'Profilimi nasıl güncellerim?',
            'Ayarlar > Kişisel Bilgiler sayfasından veya profil sayfanızdaki kalem ikonuna dokunarak bilgilerinizi güncelleyebilirsiniz.',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Bize Ulaşın'),
          _buildContactItem(
            context,
            icon: Icons.email_outlined,
            title: 'E-posta Gönder',
            subtitle: 'destek@talentmesh.com',
            onTap: () => _launchEmail('destek@talentmesh.com'),
          ),
          _buildContactItem(
            context,
            icon: Icons.language,
            title: 'Web Sitemiz',
            subtitle: 'www.talentmesh.com',
            onTap: () => _launchUrl('https://www.talentmesh.com'),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Versiyon 1.0.0',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Nasıl yardımcı olabiliriz?',
          hintStyle: GoogleFonts.inter(color: theme.textTheme.bodySmall?.color),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryAccent, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: theme.textTheme.bodySmall?.color),
      onTap: onTap,
    );
  }
}
