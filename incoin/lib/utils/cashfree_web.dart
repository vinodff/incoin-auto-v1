import 'dart:js' as js;
import 'dart:js_util' as js_util;

class CashfreeWeb {
  static Future<void> openCheckout({
    required String paymentSessionId,
    required Function() onSuccess,
    Function(String)? onFailure,
    Function()? onDismiss,
  }) async {
    try {
      final cashfree = js.context.callMethod('Cashfree', [
        js.JsObject.jsify({'mode': 'production'})
      ]);

      final options = js.JsObject.jsify({
        'paymentSessionId': paymentSessionId,
        'redirectTarget': '_modal',
      });

      final promise = cashfree.callMethod('checkout', [options]);

      await js_util.promiseToFuture(promise).then((dynamic result) {
        final jsResult = result as js.JsObject;
        if (jsResult['paymentDetails'] != null) {
          onSuccess();
        } else if (jsResult['error'] != null) {
          final err = jsResult['error'];
          onFailure?.call(err?.toString() ?? 'Payment failed');
        }
      }).catchError((dynamic e) {
        onFailure?.call(e.toString());
      });
    } catch (e) {
      onFailure?.call(e.toString());
    }
  }
}
