import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/incoin_api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkUpdateAndNavigate();
  }

  Future<void> _checkUpdateAndNavigate() async {
    // Wait for the minimum splash screen duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // final isUpdateRequired = await IncoinApiService.checkAppUpdate();

    // if (isUpdateRequired && mounted) {
    //   _showUpdateDialog();
    //   return;
    // }

    if (mounted) {
      if (SupabaseService().isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force the user to update
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: const Text('Please download the latest version of the app to continue using Incoin Auto.'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                const url = 'https://drive.google.com/file/d/1gQ3Ncfhftbdu73PDcE0pqVdhcAE2rru6/view?usp=sharing';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a simple icon as a placeholder for the logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.memory,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Incoin Auto',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automate your earnings',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
