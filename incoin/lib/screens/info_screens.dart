import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'About Us',
      sections: [
        _Section(
          icon: '🎯',
          heading: 'Our Mission',
          body: [
            'Incoin Assistant is a digital tool that helps users streamline and manage tasks efficiently. It is designed to improve workflow productivity through a simple and structured interface.',
            'We believe productivity tools should be fast, reliable, and easy to use — without unnecessary complexity. Our focus is entirely on providing a seamless task-management experience.',
          ],
        ),
        _Section(
          icon: '⚙️',
          heading: 'What We Do',
          body: [
            'Our platform provides a credit-based system that grants access to features within the application. These credits are purely for feature access and carry no monetary value.',
          ],
          bullets: [
            'Digital task management and processing',
            'Structured workflow interface for efficiency',
            'Credit-based feature access system',
            'Secure data handling and privacy protection',
          ],
        ),
        _DisclaimerSection(
          text:
              'Our platform does NOT provide any earning services, investment opportunities, or financial guarantees of any kind. Incoin Assistant is a productivity tool only.',
        ),
      ],
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Contact Us',
      sections: [
        _Section(
          icon: '📧',
          heading: 'Email Support',
          body: [
            'For any queries, support requests, or issues, reach us directly via email. We aim to respond within 24–48 hours.',
          ],
          email: 'vcontenthelper@gmail.com',
        ),
        _Section(
          icon: '💬',
          heading: 'We Can Help With',
          bullets: [
            'Technical issues with the app',
            'Account and login problems',
            'Credit purchase queries',
            'Refund requests (failed/duplicate payments)',
            'General feedback and suggestions',
          ],
        ),
        _DisclaimerSection(
          icon: '📝',
          text:
              'Please include your registered email address and a clear description of your issue. This helps us resolve your query faster.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Terms & Conditions',
      lastUpdated: 'Last updated: April 2024',
      sections: [
        _Section(
          number: '1',
          heading: 'Acceptance of Terms',
          body: [
            'By accessing or using Incoin Assistant, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you may not use our platform.',
          ],
        ),
        _Section(
          number: '2',
          heading: 'Nature of Service',
          body: [
            'Incoin Assistant is a digital productivity tool only. By using this application, you acknowledge and agree that:',
          ],
          bullets: [
            'This application does NOT guarantee any earnings or financial returns.',
            'This application is NOT an investment platform or money-making scheme.',
            'All services provided are entirely digital in nature.',
            'Credits are for feature access only and hold no monetary value.',
          ],
        ),
        _Section(
          number: '3',
          heading: 'User Responsibilities',
          body: ['You agree to:'],
          bullets: [
            'Use the platform in a lawful and responsible manner.',
            'Not attempt to reverse-engineer, hack, or exploit the application.',
            'Provide accurate information when creating an account.',
            'Keep your login credentials confidential and secure.',
          ],
        ),
        _Section(
          number: '4',
          heading: 'Account Suspension',
          body: ['We reserve the right to suspend or terminate accounts in the event of:'],
          bullets: [
            'Misuse or abuse of the platform.',
            'Violation of these Terms and Conditions.',
            'Fraudulent activity or chargebacks.',
          ],
        ),
        _Section(
          number: '5',
          heading: 'Digital Services',
          body: [
            'All services provided through Incoin Assistant are digital in nature. There are no physical goods, deliveries, or tangible products associated with this platform.',
          ],
        ),
        _Section(
          number: '6',
          heading: 'Changes to Terms',
          body: [
            'We reserve the right to update or modify these Terms at any time without prior notice. Continued use of the platform after changes constitutes your acceptance of the updated terms.',
          ],
        ),
        _Section(
          number: '7',
          heading: 'Contact',
          body: ['For questions regarding these Terms, contact:'],
          email: 'vcontenthelper@gmail.com',
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Privacy Policy',
      lastUpdated: 'Last updated: April 2024',
      sections: [
        _Section(
          number: '1',
          heading: 'Information We Collect',
          body: ['We collect basic user information to operate and improve our services:'],
          bullets: [
            'Account Information: Email address used to create your account.',
            'Usage Data: How you interact with the app (feature usage, session duration).',
            'Device Information: Basic device data to ensure compatibility.',
          ],
        ),
        _Section(
          number: '2',
          heading: 'What We Do NOT Collect',
          bullets: [
            'We do NOT store passwords on our servers.',
            'We do NOT collect payment card details — all payments go through Razorpay.',
            'We do NOT collect personally identifiable information beyond what is necessary.',
          ],
          bulletColor: 'green',
        ),
        _Section(
          number: '3',
          heading: 'How We Use Your Data',
          body: ['The information we collect is used solely to:'],
          bullets: [
            'Provide and maintain the Incoin Assistant service.',
            'Manage your account and credits.',
            'Respond to your support queries.',
            'Improve the platform\'s performance and user experience.',
          ],
        ),
        _Section(
          number: '4',
          heading: 'Data Sharing',
          body: [
            'We do not sell, trade, or share your personal data with any third parties for marketing or commercial purposes.',
            'Limited data may be shared only with trusted service providers (such as Razorpay for payment processing) strictly as necessary to operate the service.',
          ],
        ),
        _Section(
          number: '5',
          heading: 'Payment Security',
          body: [
            'All financial transactions are processed securely via Razorpay. We do not directly handle, store, or process your payment card information. All payment data is encrypted and managed by Razorpay in accordance with PCI DSS standards.',
          ],
        ),
        _Section(
          number: '6',
          heading: 'Data Retention',
          body: [
            'We retain your account data for as long as your account is active. You may request deletion of your data by contacting us.',
          ],
          email: 'vcontenthelper@gmail.com',
        ),
        _Section(
          number: '7',
          heading: 'Your Rights',
          bullets: [
            'Right to access the personal data we hold about you.',
            'Right to request correction of inaccurate data.',
            'Right to request deletion of your data.',
          ],
        ),
      ],
    );
  }
}

class RefundScreen extends StatelessWidget {
  const RefundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: 'Refund Policy',
      lastUpdated: 'Last updated: April 2024',
      sections: [
        _Section(
          number: '1',
          heading: 'General Policy',
          body: [
            'All purchases made on Incoin Assistant are for digital services (feature credits) and are generally non-refundable once the credits have been used or activated.',
            'By completing a purchase, you acknowledge and agree to this refund policy.',
          ],
        ),
        _Section(
          number: '2',
          heading: 'Eligible Refund Cases',
          body: ['Refunds may be considered only in the following exceptional circumstances:'],
          bullets: [
            'Failed Transactions: Payment deducted but credits were not added to your account.',
            'Duplicate Payments: Charged more than once for the same order due to a technical error.',
          ],
          bulletColor: 'green',
        ),
        _Section(
          number: '3',
          heading: 'Non-Eligible Cases',
          body: ['Refunds will NOT be provided for:'],
          bullets: [
            'Credits that have already been used within the application.',
            'Change of mind after a purchase.',
            'Misuse of the application leading to account suspension.',
            'Dissatisfaction with task outcomes.',
          ],
          bulletColor: 'red',
        ),
        _Section(
          number: '4',
          heading: 'How to Request a Refund',
          body: [
            'To submit a refund request, email us and include: your registered email, date and amount of transaction, Razorpay transaction ID, and reason for the refund.',
          ],
          email: 'vcontenthelper@gmail.com',
        ),
        _Section(
          number: '5',
          heading: 'Processing Time',
          body: [
            'Approved refunds will be processed within 5–7 business days back to your original payment method.',
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Shared internal widgets
// ══════════════════════════════════════════════════════════

class _InfoScaffold extends StatelessWidget {
  final String title;
  final String? lastUpdated;
  final List<Widget> sections;

  const _InfoScaffold({
    required this.title,
    required this.sections,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastUpdated != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  lastUpdated!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            ...sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: s,
                )),
          ],
        ),
      ),
    );
  }
}

// ── A single content section card ─────────────────────────
class _Section extends StatelessWidget {
  final String? icon;
  final String? number;
  final String heading;
  final List<String> body;
  final List<String> bullets;
  final String? email;
  final String? bulletColor; // 'green' | 'red' | null (default purple)

  const _Section({
    this.icon,
    this.number,
    required this.heading,
    this.body = const [],
    this.bullets = const [],
    this.email,
    this.bulletColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    Color bulletDot() {
      switch (bulletColor) {
        case 'green': return const Color(0xFF10B981);
        case 'red':   return const Color(0xFFEF4444);
        default:      return primary;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (number != null)
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        number!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ),
                  )
                else if (icon != null)
                  Text(icon!, style: const TextStyle(fontSize: 26)),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    heading,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),

            if (body.isNotEmpty || bullets.isNotEmpty || email != null)
              const SizedBox(height: 14),

            // Body paragraphs
            for (final line in body) ...[
              Text(
                line,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bullet points
            for (final b in bullets) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 10),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: bulletDot(),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Email CTA
            if (email != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Text(
                        email!,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Disclaimer / warning banner ────────────────────────────
class _DisclaimerSection extends StatelessWidget {
  final String text;
  final String icon;

  const _DisclaimerSection({
    required this.text,
    this.icon = '⚠️',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.65,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
