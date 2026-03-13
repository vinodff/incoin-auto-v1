import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Email icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: 50,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Verify Your Email',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                      ),
                ),
                const SizedBox(height: 16),

                Text(
                  'We have sent a verification link to',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInstruction(context, '1', 'Open your email inbox'),
                      const SizedBox(height: 12),
                      _buildInstruction(context, '2', 'Click the verification link in the email from Incoin'),
                      const SizedBox(height: 12),
                      _buildInstruction(context, '3', 'Come back here and login'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Didn\'t receive the email? Check your spam folder.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text(
                      'Go to Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(BuildContext context, String step, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
