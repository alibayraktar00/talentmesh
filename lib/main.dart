import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/services/meeting_reminder_service.dart';
import 'screens/auth_gate.dart';
import 'providers/theme_provider.dart';

final themeProvider = ThemeProvider();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Kullanıcı oturumu açıkken toplantı hatırlatıcıyı başlat
  final supabase = Supabase.instance.client;
  supabase.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      MeetingReminderService.instance.start();
    } else if (data.event == AuthChangeEvent.signedOut) {
      MeetingReminderService.instance.dispose();
    }
  });

  // Eğer kullanıcı zaten giriş yapmışsa hemen başlat
  if (supabase.auth.currentUser != null) {
    MeetingReminderService.instance.start();
  }

  runApp(const TalentMeshApp());
}

class TalentMeshApp extends StatelessWidget {
  const TalentMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'Talent Mesh',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}
