import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _messageAlerts = true;
  bool _connectionRequests = true;
  bool _teamUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Bildirim Ayarları',
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
          _buildSectionHeader('Genel Bildirimler'),
          _buildSwitchItem(
            title: 'Anlık Bildirimler',
            description: 'Uygulama kapalıyken telefonuna gelen bildirimler.',
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSwitchItem(
            title: 'E-posta Bildirimleri',
            description: 'Önemli güncellemelerin e-posta ile gönderilmesi.',
            value: _emailNotifications,
            onChanged: (val) => setState(() => _emailNotifications = val),
          ),
          
          _buildSectionHeader('Aktivite Bildirimleri'),
          _buildSwitchItem(
            title: 'Mesajlar',
            description: 'Yeni bir mesaj aldığında bildirim al.',
            value: _messageAlerts,
            onChanged: (val) => setState(() => _messageAlerts = val),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSwitchItem(
            title: 'Bağlantı İstekleri',
            description: 'Biri seni arkadaş olarak eklediğinde bildirim al.',
            value: _connectionRequests,
            onChanged: (val) => setState(() => _connectionRequests = val),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          _buildSwitchItem(
            title: 'Takım Güncellemeleri',
            description: 'Takımınla ilgili duyurulardan haberdar ol.',
            value: _teamUpdates,
            onChanged: (val) => setState(() => _teamUpdates = val),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bildirim tercihlerinizi buradan özelleştirebilirsiniz. Bu ayarlar sadece bu hesap için geçerlidir.',
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
