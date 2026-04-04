import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'feed_screen.dart';

/// Uygulama açıldığında oturumu kontrol eder.
/// Oturum açıksa FeedScreen, yoksa LoginScreen gösterir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data?.session;
        if (session != null) {
          return const FeedScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
