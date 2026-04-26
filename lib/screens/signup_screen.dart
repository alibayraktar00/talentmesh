import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _client = Supabase.instance.client;

  bool _obscurePassword = true;
  bool _isLoading = false;
  DateTime? _dateOfBirth;

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
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

  // Türkçe yorum: Basit e-posta doğrulaması (regex).
  bool _isValidEmail(String email) {
    final r = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return r.hasMatch(email);
  }

  // Türkçe yorum: Kullanıcı adı küçük harf, boşluksuz ve güvenli karakterlerde olmalı.
  String _normalizeUsername(String input) {
    final lower = input.trim().toLowerCase();
    // Boşlukları kaldır, izin verilen karakterler: a-z 0-9 _ .
    final noSpaces = lower.replaceAll(RegExp(r'\s+'), '');
    final cleaned = noSpaces.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    return cleaned;
  }

  Future<void> _pickDateOfBirth() async {
    if (_isLoading) return;
    final now = DateTime.now();
    final initial =
        _dateOfBirth ??
        DateTime(now.year - 18, now.month, now.day); // varsayılan: 18 yaş

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day), // ileri tarih engeli
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked == null) return;
    if (!mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd.$mm.$yyyy';
  }

  // Türkçe yorum: Username daha önce alınmış mı kontrol et.
  Future<bool> _isUsernameTaken(String username) async {
    final normalized = _normalizeUsername(username);
    // Not: 'profiles' tablosunda 'username' alanı olduğu varsayımıyla çalışır.
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('username', normalized)
        .maybeSingle();
    return existing != null;
  }

  Future<void> _signUp() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final fullName = _fullNameController.text.trim();
    final rawUsername = _usernameController.text;
    final username = _normalizeUsername(rawUsername);
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final dob = _dateOfBirth;

    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        dob == null) {
      _showError('Lütfen tüm alanları doldurun.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showError('Geçerli bir e-posta adresi girin.');
      return;
    }
    if (password.length < 6) {
      _showError('Şifre en az 6 karakter olmalı.');
      return;
    }
    if (username.length < 3) {
      _showError('Kullanıcı adı en az 3 karakter olmalı.');
      return;
    }

    // Türkçe yorum: Form doğrulaması (TextFormField validator'ları) ek güvenlik.
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isLoading = true);
    try {
      // Türkçe yorum: Önce username müsait mi kontrol ediyoruz (arkadaş arama için kritik).
      final taken = await _isUsernameTaken(username);
      if (taken) {
        _showError('Bu kullanıcı adı zaten kullanılıyor.');
        return;
      }

      // Türkçe yorum: Supabase Auth ile kullanıcı oluştur.
      final res = await _authService.signUp(
        email: email,
        password: password,
        // Türkçe yorum: Auth trigger'larında kullanılabilmesi için metadata gönderiyoruz.
        data: {
          'full_name': fullName,
          'username': username,
          'phone': phone,
          'date_of_birth': dob.toIso8601String(),
        },
      );
      if (res.user == null) {
        _showError('Kayıt başarısız. Lütfen tekrar deneyin.');
        return;
      }

      // Türkçe yorum: Profiles insert işlemini trigger yönettiği için burada manuel insert yapılmıyor.
      if (res.session == null) {
        _showError(
          'Kayıt tamamlandı ancak oturum açılamadı. Lütfen e-postanızı doğrulayın.',
        );
        return;
      }

      _showSuccess('Kayıt başarılı! Ana sayfaya yönlendiriliyorsunuz.');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } on PostgrestException catch (e) {
      // Türkçe yorum: DB insert veya username kontrol hataları burada yakalanır.
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.headingText,
            size: 20,
          ),
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
                child: Form(
                  key: _formKey,
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
                      const SizedBox(height: 28),

                      // ── Tam Ad ──
                      TextFormField(
                        controller: _fullNameController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Tam Ad',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Tam ad zorunludur.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Kullanıcı Adı ──
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          // Türkçe yorum: kullanıcı adı sadece a-z 0-9 _ . ve boşluksuz olacak.
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_.]|\s'),
                          ),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final normalized = _normalizeUsername(
                              newValue.text,
                            );
                            return TextEditingValue(
                              text: normalized,
                              selection: TextSelection.collapsed(
                                offset: normalized.length,
                              ),
                            );
                          }),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Kullanıcı Adı (küçük harf, boşluksuz)',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                        validator: (v) {
                          final raw = (v ?? '').trim();
                          final normalized = _normalizeUsername(raw);
                          if (normalized.isEmpty) {
                            return 'Kullanıcı adı zorunludur.';
                          }
                          if (normalized.length < 3) {
                            return 'Kullanıcı adı en az 3 karakter olmalı.';
                          }
                          if (normalized !=
                              raw.toLowerCase().replaceAll(' ', '')) {
                            return 'Kullanıcı adı küçük harf ve boşluksuz olmalı.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Email ──
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'E-posta',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                        validator: (v) {
                          final email = (v ?? '').trim();
                          if (email.isEmpty) return 'E-posta zorunludur.';
                          if (!_isValidEmail(email)) {
                            return 'Geçerli bir e-posta girin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Telefon ──
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Cep Telefonu',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                        validator: (v) {
                          final phone = (v ?? '').trim();
                          if (phone.isEmpty) return 'Telefon zorunludur.';
                          if (phone.length < 10) {
                            return 'Telefon numarası eksik görünüyor.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Doğum Günü ──
                      InkWell(
                        onTap: _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(14),
                        child: IgnorePointer(
                          ignoring: true,
                          child: TextFormField(
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: _dateOfBirth == null
                                  ? 'Doğum Günü'
                                  : _formatDate(_dateOfBirth!),
                              prefixIcon: const Icon(
                                Icons.cake_outlined,
                                color: AppColors.mutedText,
                                size: 20,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 52,
                              ),
                              suffixIcon: const Icon(
                                Icons.date_range_outlined,
                                color: AppColors.mutedText,
                                size: 20,
                              ),
                            ),
                            validator: (_) {
                              if (_dateOfBirth == null) {
                                return 'Doğum tarihi zorunludur.';
                              }
                              final now = DateTime.now();
                              if (_dateOfBirth!.isAfter(now)) {
                                return 'İleri tarih seçilemez.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Şifre ──
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Şifre (en az 6 karakter)',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 52,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.mutedText,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final p = v ?? '';
                          if (p.isEmpty) return 'Şifre zorunludur.';
                          if (p.length < 6) {
                            return 'Şifre en az 6 karakter olmalı.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _isLoading ? null : _signUp(),
                      ),
                      const SizedBox(height: 22),

                      // ── Kayıt Ol Butonu ──
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
                      const SizedBox(height: 18),

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
      ),
    );
  }
}
