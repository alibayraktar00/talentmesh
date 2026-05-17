import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ProfileService _profileService = ProfileService();
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _messageAlerts = true;
  bool _connectionRequests = true;
  bool _teamUpdates = true;
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
          _pushNotifications = profile['push_notifications'] ?? true;
          _emailNotifications = profile['email_notifications'] ?? true;
          _messageAlerts = profile['message_alerts'] ?? true;
          _connectionRequests = profile['connection_requests'] ?? true;
          _teamUpdates = profile['team_updates'] ?? true;
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
            content: Text('Bildirim ayarları güncellendi'),
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
          'Bildirim Ayarları',
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
          _buildSectionHeader(context, 'Genel Bildirimler'),
          _buildSwitchItem(
            context,
            title: 'Anlık Bildirimler',
            description: 'Uygulama kapalıyken telefonuna gelen bildirimler.',
            value: _pushNotifications,
            onChanged: (val) {
              setState(() => _pushNotifications = val);
              _updateSetting('push_notifications', val);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),
          _buildSwitchItem(
            context,
            title: 'E-posta Bildirimleri',
            description: 'Önemli güncellemelerin e-posta ile gönderilmesi.',
            value: _emailNotifications,
            onChanged: (val) {
              setState(() => _emailNotifications = val);
              _updateSetting('email_notifications', val);
            },
          ),
          
          _buildSectionHeader(context, 'Aktivite Bildirimleri'),
          _buildSwitchItem(
            context,
            title: 'Mesajlar',
            description: 'Yeni bir mesaj aldığında bildirim al.',
            value: _messageAlerts,
            onChanged: (val) {
              setState(() => _messageAlerts = val);
              _updateSetting('message_alerts', val);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),
          _buildSwitchItem(
            context,
            title: 'Bağlantı İstekleri',
            description: 'Biri seni arkadaş olarak eklediğinde bildirim al.',
            value: _connectionRequests,
            onChanged: (val) {
              setState(() => _connectionRequests = val);
              _updateSetting('connection_requests', val);
            },
          ),
          Divider(height: 1, color: theme.dividerColor),
          _buildSwitchItem(
            context,
            title: 'Takım Güncellemeleri',
            description: 'Takımınla ilgili duyurulardan haberdar ol.',
            value: _teamUpdates,
            onChanged: (val) {
              setState(() => _teamUpdates = val);
              _updateSetting('team_updates', val);
            },
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bildirim tercihlerinizi buradan özelleştirebilirsiniz. Bu ayarlar sadece bu hesap için geçerlidir.',
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
    final theme = Theme.of(context);
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
