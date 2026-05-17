import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
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
          content: Text('common.error_load'.tr(), style: GoogleFonts.inter()),
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
          content: Text('common.saved'.tr(), style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryAccent,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('common.error_save'.tr(), style: GoogleFonts.inter()),
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
        title: Text('notification_settings.title'.tr(),
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
              _header('notification_settings.activity_notifications'.tr()),
              _switchItem(
                title: 'notification_settings.messages'.tr(),
                description: 'notification_settings.messages_desc'.tr(),
                value: _messageAlerts,
                onChanged: (v) => _toggle('messages', v),
              ),
              const Divider(height: 1, color: AppColors.inputBorder),
              _switchItem(
                title: 'notification_settings.connection_requests'.tr(),
                description: 'notification_settings.connection_requests_desc'.tr(),
                value: _connectionRequests,
                onChanged: (v) => _toggle('connections', v),
              ),
              const Divider(height: 1, color: AppColors.inputBorder),
              _switchItem(
                title: 'notification_settings.team_updates'.tr(),
                description: 'notification_settings.team_updates_desc'.tr(),
                value: _teamUpdates,
                onChanged: (v) => _toggle('team', v),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'notification_settings.footer_info'.tr(),
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
