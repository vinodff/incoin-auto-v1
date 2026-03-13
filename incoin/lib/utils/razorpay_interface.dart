import 'package:flutter/foundation.dart';

abstract class RazorpayWeb {
  static void openCheckout({
    required String key,
    required num amount,
    required String name,
    required String description,
    required String? email,
    required String? contact,
    required Function(String) onSuccess,
    Function(int, String)? onFailure,
    Function()? onDismiss,
  }) {
    throw UnimplementedError('openCheckout is only available on Web');
  }
}
