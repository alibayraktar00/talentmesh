import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';

class VisibilitySettingsScreen extends StatefulWidget {
  const VisibilitySettingsScreen({super.key});

  @override
  State<VisibilitySettingsScreen> createState() => _VisibilitySettingsScreenState();
}

class _VisibilitySettingsScreenState extends State<VisibilitySettingsScreen> {
  final ProfileService _profileService = ProfileService();
  bool _isProfilePublic = true;
  bool _showActiveStatus = true;
  bool _showEmail = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final profile = await _profileService.fetchProfile();
      if (profile != null && mounted) {
        setState(() {
          _isProfilePublic = profile['is_profile_public'] ?? true;
          _showActiveStatus = profile['show_active_status'] ?? true;
          _showEmail = profile['show_email'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String field, bool value) async {
    try {
      await _profileService.updateDynamicProfileField(field, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayarlar güncellendi'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayarlar güncellenirken hata oluştu')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Görünürlük',
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
        : ListView(
        children: [
          _buildSectionHeader(context, 'Profil Görünürlüğü'),
          _buildSwitchItem(
            context,
            title: 'Profilimi Herkese Aç',
            description: 'Kapalıyken profilinizi sadece arkadaşlarınız görebilir.',
            value: _isProfilePublic,
            onChanged: (val) {
              setState(() => _isProfilePublic = val);
              _updateSetting('is_profile_public', val);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),
          
          _buildSectionHeader(context, 'Durum Bilgisi'),
          _buildSwitchItem(
            context,
            title: 'Aktiflik Durumu',
            description: 'Çevrimiçi olduğunuzda arkadaşlarınızın bunu görmesine izin verin.',
            value: _showActiveStatus,
            onChanged: (val) {
              setState(() => _showActiveStatus = val);
              _updateSetting('show_active_status', val);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),

          _buildSectionHeader(context, 'İletişim Bilgileri'),
          _buildSwitchItem(
            context,
            title: 'E-posta Adresini Göster',
            description: 'E-posta adresinizin profilinizde görünmesini sağlar.',
            value: _showEmail,
            onChanged: (val) {
              setState(() => _showEmail = val);
              _updateSetting('show_email', val);
            },
          ),
          
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bu ayarlar TalentMesh üzerindeki deneyiminizi nasıl yönettiğinizi belirler. Değişiklikler anında uygulanır.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
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

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.textTheme.bodySmall?.color,
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
