import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/connect_incoin_screen.dart';
import 'screens/buy_credits_screen.dart';
import 'screens/order_logs_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/info_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cufwqjeqczitnllzpkea.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1ZndxamVxY3ppdG5sbHpwa2VhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMzI3MjEsImV4cCI6MjA4ODgwODcyMX0.dnc5FxwfydBuspDy_SoBPV6195Gc2N69N6-3nMlriOQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incoin Auto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/connect_incoin': (context) => const ConnectIncoinScreen(),
        '/buy_credits': (context) => const BuyCreditsScreen(),
        '/order_logs': (context) => const OrderLogsScreen(),
        '/verify_email': (context) {
          final email = ModalRoute.of(context)!.settings.arguments as String? ?? '';
          return EmailVerificationScreen(email: email);
        },
        '/about':   (context) => const AboutScreen(),
        '/contact': (context) => const ContactScreen(),
        '/terms':   (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/refund':  (context) => const RefundScreen(),
      },
    );
  }
}
