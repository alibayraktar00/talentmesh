import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import 'profile_screen.dart';
import 'visibility_settings_screen.dart';
import 'security_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'help_center_screen.dart';
import '../core/services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Oturumu Kapat', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Oturumu kapatmak istediğinize emin misiniz?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Çıkış Yap', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authService.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: GoogleFonts.inter(
            color: AppColors.headingText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.headingText, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // User Header Section
          _buildUserHeader(context),
          
          const Divider(height: 1, thickness: 1, color: AppColors.inputBorder),
          
          // Settings Categories
          _buildSectionHeader('Hesap Tercihleri'),
          _buildLinkedInStyleItem(
            icon: Icons.person_outline,
            title: 'Kişisel Bilgiler',
            description: 'İsim, unvan ve konum bilgilerini yönet',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          _buildLinkedInStyleItem(
            icon: Icons.visibility_outlined,
            title: 'Görünürlük',
            description: 'Profilinin kimler tarafından görülebileceğini seç',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisibilitySettingsScreen(),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          _buildSectionHeader('Güvenlik'),
          _buildLinkedInStyleItem(
            icon: Icons.lock_outline,
            title: 'Oturum Açma ve Güvenlik',
            description: 'E-posta, telefon ve şifre ayarları',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecuritySettingsScreen(),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          _buildSectionHeader('Bildirimler'),
          _buildLinkedInStyleItem(
            icon: Icons.notifications_none,
            title: 'Bildirim Ayarları',
            description: 'E-posta ve uygulama içi bildirimler',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          _buildSectionHeader('Destek'),
          _buildLinkedInStyleItem(
            icon: Icons.help_outline,
            title: 'Yardım Merkezi',
            description: 'Sıkça sorulan sorular ve destek hattı',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpCenterScreen(),
                ),
              );
            },
          ),
          _buildLinkedInStyleItem(
            icon: Icons.info_outline,
            title: 'Hakkında',
            description: 'Kullanım koşulları ve yasal bilgiler',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'TalentMesh',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.hub_outlined,
                  color: AppColors.primaryAccent,
                  size: 40,
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () => _handleLogout(context),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Oturumu Kapat',
                style: GoogleFonts.inter(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.chipBg,
            child: Icon(Icons.person, color: AppColors.primaryAccent, size: 35),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kullanıcı Adı', // Buraya dinamik veri gelebilir
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headingText,
                  ),
                ),
                Text(
                  'Profilinizi yönetin',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.headingText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLinkedInStyleItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.bodyText, size: 22),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
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
          ],
        ),
      ),
    );
  }
}
