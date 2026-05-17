import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/theme/app_colors.dart';
import '../core/services/auth_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _client = Supabase.instance.client;
  final _authService = AuthService();
  late String _userEmail;

  @override
  void initState() {
    super.initState();
    _userEmail = _authService.currentUser?.email ?? 'security_settings.loading'.tr();
  }

  void _showUnderDevelopment(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('security_settings.feature_soon'.tr(args: [feature])),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('security_settings.change_password'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'security_settings.new_password'.tr()),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'security_settings.confirm_password'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () {
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security_settings.error_password_length'.tr())));
                return;
              }
              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security_settings.error_password_match'.tr())));
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('common.update'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _client.auth.updateUser(UserAttributes(password: passwordController.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security_settings.success_password_update'.tr())));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security_settings.error_prefix'.tr(args: [e.toString()]))));
        }
      }
    }
  }

  Future<void> _handleUpdateEmail() async {
    final emailController = TextEditingController(text: _userEmail);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('security_settings.update_email'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(labelText: 'security_settings.new_email'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.update'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _client.auth.updateUser(UserAttributes(email: emailController.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('security_settings.success_email_update'.tr())),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('security_settings.error_prefix'.tr(args: [e.toString()]))));
        }
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
          'security_settings.title'.tr(),
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
        children: [
          _buildSectionHeader(context, 'security_settings.account_access'.tr()),
          _buildSecurityItem(
            context,
            title: 'security_settings.email_address'.tr(),
            value: _userEmail,
            onTap: _handleUpdateEmail,
          ),
          Divider(height: 1, color: theme.dividerColor),
          _buildSecurityItem(
            context,
            title: 'security_settings.phone_number'.tr(),
            value: 'security_settings.not_added'.tr(),
            onTap: () => _showUnderDevelopment('security_settings.add_phone'.tr()),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _buildSecurityItem(
            context,
            title: 'security_settings.change_password'.tr(),
            value: 'security_settings.update_password_desc'.tr(),
            onTap: _handleChangePassword,
          ),

          const SizedBox(height: 32),
          _buildDangerZone(context),
          const SizedBox(height: 40),
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

  Widget _buildSecurityItem(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'security_settings.account_management'.tr(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('security_settings.close_account'.tr()),
                  content: Text('security_settings.close_account_confirm'.tr()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common.cancel'.tr())),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('security_settings.close_account'.tr(), style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                _showUnderDevelopment('security_settings.close_account_real'.tr());
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'security_settings.close_account'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
