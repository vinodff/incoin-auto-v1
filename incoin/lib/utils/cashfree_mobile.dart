class CashfreeWeb {
  static Future<void> openCheckout({
    required String paymentSessionId,
    required Function() onSuccess,
    Function(String)? onFailure,
    Function()? onDismiss,
  }) async {
    // No-op stub for non-web platforms — buy_credits_screen uses cashfree_pg directly on mobile
  }
}
