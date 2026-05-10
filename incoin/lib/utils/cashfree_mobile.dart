import 'package:url_launcher/url_launcher.dart';

class CashfreeWeb {
  /// Mobile flow: open the hosted checkout HTML on the whitelisted GitHub Pages
  /// domain in the system browser. The user completes payment there and returns
  /// to the app. Confirmation is handled by the calling screen.
  static Future<void> openCheckout({
    required String paymentSessionId,
    required Function() onSuccess,
    Function(String)? onFailure,
    Function()? onDismiss,
  }) async {
    final url = Uri.parse(
      'https://vinodff.github.io/incoin-auto-v1/cashfree-checkout.html?session_id=$paymentSessionId',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        onFailure?.call('Could not open browser');
      }
    } catch (e) {
      onFailure?.call(e.toString());
    }
  }
}
