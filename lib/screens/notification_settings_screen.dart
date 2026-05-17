import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final ProfileService _profileService = ProfileService();

  bool _messageAlerts = true;
  bool _connectionRequests = true;
  bool _teamUpdates = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _profileService.fetchNotificationSettings();
      if (mounted) {
        setState(() {
          _messageAlerts = settings['notif_messages'] ?? true;
          _connectionRequests = settings['notif_connections'] ?? true;
          _teamUpdates = settings['notif_team_updates'] ?? true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ayarlar yüklenemedi.', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _profileService.updateNotificationSettings(
        messages: _messageAlerts,
        connections: _connectionRequests,
        teamUpdates: _teamUpdates,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Kaydedildi.', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryAccent,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Kaydedilemedi.', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle(String field, bool val) async {
    setState(() {
      if (field == 'messages') _messageAlerts = val;
      if (field == 'connections') _connectionRequests = val;
      if (field == 'team') _teamUpdates = val;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('Bildirim Ayarları',
            style: GoogleFonts.inter(
                color: AppColors.headingText,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.headingText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryAccent),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : ListView(children: [
              _header('Aktivite Bildirimleri'),
              _switchItem(
                title: 'Mesajlar',
                description: 'Yeni bir mesaj aldığında bildirim al.',
                value: _messageAlerts,
                onChanged: (v) => _toggle('messages', v),
              ),
              const Divider(height: 1, color: AppColors.inputBorder),
              _switchItem(
                title: 'Bağlantı İstekleri',
                description: 'Biri seni arkadaş olarak eklediğinde bildirim al.',
                value: _connectionRequests,
                onChanged: (v) => _toggle('connections', v),
              ),
              const Divider(height: 1, color: AppColors.inputBorder),
              _switchItem(
                title: 'Takım Güncellemeleri',
                description: 'Takımınla ilgili duyurulardan haberdar ol.',
                value: _teamUpdates,
                onChanged: (v) => _toggle('team', v),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bu bildirimler uygulama içi olarak çalışır. Kapatılan bildirimler sana gönderilmez.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText, height: 1.5),
                ),
              ),
            ]),
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryAccent,
                letterSpacing: 0.5)),
      );

  Widget _switchItem({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.headingText)),
            const SizedBox(height: 4),
            Text(description,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.mutedText)),
          ]),
        ),
        Switch.adaptive(
          value: value,
          onChanged: _isSaving ? null : onChanged,
          activeTrackColor: AppColors.primaryAccent,
        ),
      ]),
    );
  }
}
