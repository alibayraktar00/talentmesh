import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Tüm alanları doldurun.');
      return;
    }
    if (!email.contains('@')) {
      _showError('Geçerli bir email adresi girin.');
      return;
    }
    if (password.length < 6) {
      _showError('Şifre en az 6 karakter olmalı.');
      return;
    }
    if (password != confirm) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _authService.signUp(email: email, password: password);
      if (res.user != null) {
        if (res.session != null) {
          // Supabase otomatik oturum açar (email doğrulaması kapalıysa).
          // Kullanıcının özellikle 'Login' ekranından tekrar girmesi istendiği için çıkış yapıyoruz.
          await _authService.signOut();
          _showSuccess('Kayıt başarılı! Lütfen giriş yapın.');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) Navigator.of(context).pop();
        } else {
          // Email doğrulama açıkken olan senaryo
          _showSuccess('Kayıt başarılı! Email kutunuzu kontrol edin.');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) Navigator.of(context).pop();
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Kayıt olunamadı. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.headingText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hesap Oluştur',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Talent Mesh\'e katıl ve ekibini bul.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Email ──
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Email Adresi',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppColors.mutedText, size: 20),
                        prefixIconConstraints: BoxConstraints(minWidth: 52),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Şifre ──
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Şifre (en az 6 karakter)',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColors.mutedText, size: 20),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 52),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Şifre Tekrar ──
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Şifre Tekrar',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColors.mutedText, size: 20),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 52),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                          child: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Kayıt Ol Butonu ──
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? const LinearGradient(
                                colors: [Colors.grey, Colors.grey])
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryAccent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Kayıt Ol',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Zaten hesabın var mı? ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zaten hesabın var mı? ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.bodyText,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Giriş Yap',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
