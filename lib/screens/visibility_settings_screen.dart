import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';

class VisibilitySettingsScreen extends StatefulWidget {
  const VisibilitySettingsScreen({super.key});

  @override
  State<VisibilitySettingsScreen> createState() =>
      _VisibilitySettingsScreenState();
}

class _VisibilitySettingsScreenState extends State<VisibilitySettingsScreen> {
  final ProfileService _profileService = ProfileService();

  bool _isProfilePublic = true;
  bool _showEmail = false;
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
      final settings = await _profileService.fetchVisibilitySettings();
      if (mounted) {
        setState(() {
          _isProfilePublic = settings['is_profile_public'] ?? true;
          _showEmail = settings['show_email'] ?? false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('visibility_settings.error_load'.tr(), style: GoogleFonts.inter()),
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
      await _profileService.updateVisibilitySettings(
        isProfilePublic: _isProfilePublic,
        showEmail: _showEmail,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('visibility_settings.success_save'.tr(), style: GoogleFonts.inter()),
          backgroundColor: AppColors.primaryAccent,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('visibility_settings.error_save'.tr(), style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle(String field, bool val) async {
    setState(() {
      if (field == 'is_profile_public') _isProfilePublic = val;
      if (field == 'show_email') _showEmail = val;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('visibility_settings.title'.tr(),
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
              _header('visibility_settings.profile_visibility'.tr()),
              _switchItem(
                title: 'visibility_settings.make_public'.tr(),
                description: 'visibility_settings.make_public_desc'.tr(),
                value: _isProfilePublic,
                onChanged: (v) => _toggle('is_profile_public', v),
              ),
              const Divider(height: 1, color: AppColors.inputBorder),
              _header('visibility_settings.contact_info'.tr()),
              _switchItem(
                title: 'visibility_settings.show_email'.tr(),
                description: 'visibility_settings.show_email_desc'.tr(),
                value: _showEmail,
                onChanged: (v) => _toggle('show_email', v),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'visibility_settings.footer_info'.tr(),
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
