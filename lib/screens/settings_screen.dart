import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';
import 'profile_screen.dart';
import 'visibility_settings_screen.dart';
import 'security_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'help_center_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileService _profileService = ProfileService();

  String _displayName = '';
  String? _avatarUrl;
  bool _headerLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserHeader();
  }

  Future<void> _loadUserHeader() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (profile != null && mounted) {
        final fullName = (profile['full_name'] ?? '').toString().trim();
        final username = (profile['username'] ?? '').toString().trim();
        setState(() {
          _displayName =
              fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : 'Kullanıcı');
          _avatarUrl = profile['avatar_url']?.toString();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _headerLoading = false);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.logout'.tr(),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('settings.logout_confirm_msg'.tr(),
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('settings.cancel'.tr(),
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('settings.logout_button'.tr(),
                style: GoogleFonts.inter(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.language'.tr(),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('settings.turkish'.tr()),
              trailing: context.locale.languageCode == 'tr'
                  ? const Icon(Icons.check, color: AppColors.primaryAccent)
                  : null,
              onTap: () {
                context.setLocale(const Locale('tr'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('settings.english'.tr()),
              trailing: context.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: AppColors.primaryAccent)
                  : null,
              onTap: () {
                context.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'settings.title'.tr(),
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
          _buildSectionHeader('settings.account_preferences'.tr()),
          _buildLinkedInStyleItem(
            icon: Icons.person_outline,
            title: 'settings.personal_info'.tr(),
            description: 'settings.personal_info_desc'.tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          _buildLinkedInStyleItem(
            icon: Icons.visibility_outlined,
            title: 'settings.visibility'.tr(),
            description: 'settings.visibility_desc'.tr(),
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
          _buildSectionHeader('settings.language'.tr()),
          _buildLinkedInStyleItem(
            icon: Icons.language,
            title: 'settings.language'.tr(),
            description: context.locale.languageCode == 'tr' ? 'settings.turkish'.tr() : 'settings.english'.tr(),
            onTap: _showLanguageDialog,
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('settings.security'.tr()),
          _buildLinkedInStyleItem(
            icon: Icons.lock_outline,
            title: 'settings.signin_security'.tr(),
            description: 'settings.signin_security_desc'.tr(),
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
          _buildSectionHeader('settings.notifications'.tr()),
          _buildLinkedInStyleItem(
            icon: Icons.notifications_none,
            title: 'settings.notification_settings'.tr(),
            description: 'settings.notification_settings_desc'.tr(),
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
          _buildSectionHeader('settings.support'.tr()),
          _buildLinkedInStyleItem(
            icon: Icons.help_outline,
            title: 'settings.help_center'.tr(),
            description: 'settings.help_center_desc'.tr(),
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
            title: 'settings.about'.tr(),
            description: 'settings.about_desc'.tr(),
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
                'settings.logout'.tr(),
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
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.chipBg,
            backgroundImage:
                (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                    ? NetworkImage(_avatarUrl!)
                    : null,
            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                ? const Icon(Icons.person,
                    color: AppColors.primaryAccent, size: 35)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerLoading
                    ? Container(
                        width: 120,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Text(
                        _displayName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.headingText,
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  'settings.manage_profile'.tr(),
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
                MaterialPageRoute(
                    builder: (context) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.mutedText),
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
