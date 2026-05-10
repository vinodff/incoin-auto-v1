import 'dart:convert';
import 'package:http/http.dart' as http;

class CashfreeService {
  static const _edgeFnUrl =
      'https://cufwqjeqczitnllzpkea.supabase.co/functions/v1/cashfree-create-order';

  /// Creates a Cashfree order via Supabase Edge Function and returns the
  /// payment_session_id, or throws a descriptive error string.
  static Future<String> createOrder({
    required int amountInRupees,
    required String customerEmail,
    String? customerPhone,
  }) async {
    final response = await http.post(
      Uri.parse(_edgeFnUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amountInRupees,
        'email': customerEmail,
        'phone': customerPhone ?? '9999999999',
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && data['payment_session_id'] != null) {
      return data['payment_session_id'] as String;
    }

    throw data['error'] ?? 'Order creation failed (${response.statusCode})';
  }
}
