import 'dart:js' as js;

class RazorpayWeb {
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
    final options = {
      'key': key,
      'amount': (amount * 100).toInt(),
      'name': name,
      'description': description,
      'prefill': {
        'contact': contact ?? '',
        'email': email ?? '',
      },
      'handler': js.allowInterop((response) {
        if (response['razorpay_payment_id'] != null) {
          onSuccess(response['razorpay_payment_id'] as String);
        }
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          if (onDismiss != null) onDismiss();
        }),
      },
    };

    try {
      final rzp = js.JsObject(js.context['Razorpay'], [js.JsObject.jsify(options)]);
      rzp.callMethod('open');
    } catch (e) {
      if (onFailure != null) onFailure(0, e.toString());
    }
  }
}
