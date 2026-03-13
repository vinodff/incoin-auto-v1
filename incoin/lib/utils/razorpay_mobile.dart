class RazorpayWeb {
  static void openCheckout({
    required String key,
    required num amount,
    required String name,
    required String description,
    required String? email,
    required String? contact,
    required Function(String) onSuccess,
    dynamic onFailure,
    dynamic onDismiss,
  }) {
    // No-op for mobile
  }
}
