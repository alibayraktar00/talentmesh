import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _client = Supabase.instance.client;

  bool _obscurePassword = true;
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
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
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

  // Türkçe yorum: Girilen değer e-posta mı kontrol eder.
  bool _isEmail(String input) => input.contains('@');

  // Türkçe yorum: Sadece rakam ya da + ile başlayıp rakamlarla devam eden telefon kontrolü.
  bool _isPhone(String input) => RegExp(r'^\+?\d+$').hasMatch(input);

  // Türkçe yorum: Supabase'den gelen yaygın İngilizce hataları Türkçeleştiriyoruz.
  String _translateAuthError(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Kullanıcı bilgileri hatalı. Lütfen tekrar deneyin.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta doğrulaması yapılmamış. Lütfen e-posta kutunuzu kontrol edin.';
    }
    if (lower.contains('too many requests')) {
      return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'İnternet bağlantısı sorunu. Lütfen bağlantınızı kontrol edin.';
    }
    if (lower.contains('user not found')) {
      return 'Böyle bir kullanıcı bulunamadı.';
    }
    if (lower.contains('database error')) {
      return 'Sunucu tarafında bir veritabanı hatası oluştu.';
    }

    return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
  }

  Future<void> _signIn() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showError('Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isEmail(identifier)) {
        // Türkçe yorum: '@' içeriyorsa e-posta ile giriş.
        await _authService.signIn(email: identifier, password: password);
      } else if (_isPhone(identifier)) {
        // Türkçe yorum: Telefon formatına uyuyorsa phone ile giriş.
        await _client.auth.signInWithPassword(
          phone: identifier,
          password: password,
        );
      } else {
        // Türkçe yorum: Username ise önce RPC ile e-postaya çeviriyoruz.
        final response = await _client.rpc(
          'get_email_by_username',
          params: {'p_username': identifier.toLowerCase()},
        );

        final emailFromUsername = (response ?? '').toString().trim();
        if (emailFromUsername.isEmpty) {
          _showError('Böyle bir kullanıcı bulunamadı.');
          return;
        }

        await _client.auth.signInWithPassword(
          email: emailFromUsername,
          password: password,
        );
      }
      // AuthGate otomatik olarak FeedScreen'e yönlendirir
    } on AuthException catch (e) {
      _showError(_translateAuthError(e.message));
    } on PostgrestException catch (e) {
      _showError(_translateAuthError(e.message));
    } catch (_) {
      _showError('Giriş yapılamadı. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  children: [
                    const SizedBox(height: 40),

                    // ── Logo ──
                    _buildLogo(),
                    const SizedBox(height: 12),

                    Text(
                      'TALENT MESH',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Build your dream team',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mutedText,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── Identifier Field (Email/Phone/Username) ──
                    TextField(
                      controller: _identifierController,
                      keyboardType: TextInputType.text,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'E-posta, Telefon veya Kullanıcı Adı',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: AppColors.mutedText,
                          size: 20,
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 52),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Password Field ──
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.mutedText,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 52,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
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
                    const SizedBox(height: 28),

                    // ── Sign In Button ──
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? const LinearGradient(
                                colors: [Colors.grey, Colors.grey],
                              )
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
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
                                'Giriş Yap',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Forgot Password ──
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── Sign Up Link ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.bodyText,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  );
                                },
                          child: Text(
                            'Sign Up',
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

  Widget _buildLogo() {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _CollaborationLogoPainter()),
    );
  }
}

class _CollaborationLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint accentPaint = Paint()
      ..color = AppColors.primaryAccent
      ..style = PaintingStyle.fill;

    final Paint darkPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;

    final Paint arcPaint = Paint()
      ..color = AppColors.primaryAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx - 22, cy - 18), 10, accentPaint);
    final leftBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 22, cy + 8), width: 16, height: 28),
      const Radius.circular(8),
    );
    canvas.drawRRect(leftBody, accentPaint);

    canvas.drawCircle(Offset(cx + 22, cy - 18), 10, darkPaint);
    final rightBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + 22, cy + 8), width: 16, height: 28),
      const Radius.circular(8),
    );
    canvas.drawRRect(rightBody, darkPaint);

    final arcPath = Path()
      ..moveTo(cx - 12, cy)
      ..quadraticBezierTo(cx, cy - 14, cx + 12, cy);
    canvas.drawPath(arcPath, arcPaint);

    final dotPaint = Paint()
      ..color = AppColors.primaryAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - 6), 2.5, dotPaint);
    canvas.drawCircle(Offset(cx - 6, cy + 4), 2, dotPaint);
    canvas.drawCircle(Offset(cx + 6, cy + 4), 2, dotPaint);

    final meshPaint = Paint()
      ..color = AppColors.primaryAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx - 6, cy + 4), meshPaint);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx + 6, cy + 4), meshPaint);
    canvas.drawLine(Offset(cx - 6, cy + 4), Offset(cx + 6, cy + 4), meshPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
