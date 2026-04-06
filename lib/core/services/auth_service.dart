import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  /// Mevcut kullanıcı (null ise oturum yok)
  User? get currentUser => _client.auth.currentUser;

  /// Auth durum değişikliklerini dinle
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Giriş yap
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Kayıt ol
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Şifre sıfırlama e-postası gönder
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
