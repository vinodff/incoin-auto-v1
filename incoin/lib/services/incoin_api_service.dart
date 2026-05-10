import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// ──────────────────────────────────────────────────────────────────
// App constants — must match the Android APK signing constants
// ──────────────────────────────────────────────────────────────────
const _appVersion  = '46';
const _appId       = 'xyz.indianx.app';
const _clientType  = 'Android';
const _osVersion   = '30';
const _gaid        = 'd802a45a-8b82-45a7-932f-abcdef123456';
const _androidId   = 'a1b2c3d4e5f6g7h8';
const _language    = 'en';
const _baseUrl     = 'https://api.incoinpay.net';

// ──────────────────────────────────────────────────────────────────
// Result types
// ──────────────────────────────────────────────────────────────────

class CaptchaResult {
  final String token;
  final Uint8List imageBytes;
  const CaptchaResult({required this.token, required this.imageBytes});
}

class LoginResult {
  final bool success;
  final String? authToken;
  final String? errorMessage;
  const LoginResult({required this.success, this.authToken, this.errorMessage});
}

// ──────────────────────────────────────────────────────────────────
// IncoinApiService
// ──────────────────────────────────────────────────────────────────

class IncoinApiService {
  static final _client = http.Client();

  // ── HMAC-SHA1 signing (mirrors the Python and Android logic) ────

  static String _generateSign(
    Map<String, dynamic> bodyParams,
    Map<String, String> headerParams,
    String appSecret,
  ) {
    final all = <String, dynamic>{...bodyParams, ...headerParams};
    final entries = all.entries.toList()
      ..sort((a, b) => a.value.toString().compareTo(b.value.toString()));

    final signStr = entries
        .where((e) => e.value is String || e.value is num)
        .map((e) => e.value.toString())
        .join();

    final key  = utf8.encode(appSecret);
    final msg  = utf8.encode(signStr);
    final hmac = Hmac(sha1, key);
    return hmac.convert(msg).toString();
  }

  // ── Base headers (no token) ─────────────────────────────────────

  static Map<String, String> _baseHeaders({
    String clientKey   = '',
    String sign        = '',
    String? token,
    String? timestamp,
  }) {
    final ts = timestamp ?? '${DateTime.now().millisecondsSinceEpoch}';
    return {
      'timestamp':  ts,
      'version':    _appVersion,
      'OSVersion':  _osVersion,
      'clientKey':  clientKey,
      'clientType': _clientType,
      'appId':      _appId,
      'language':   _language,
      'gaid':       _gaid,
      'androidId':  _androidId,
      'sign':       sign,
      if (token != null) 'token': token,
      'Content-Type': 'application/json',
    };
  }

  // ── Generic signed API request (mirrors Python _api_request) ────

  static Future<Map<String, dynamic>?> apiRequest(
    String endpoint, {
    Map<String, dynamic>? bodyParams,
    required String appKey,
    required String appSecret,
    String? token,
    String method = 'POST',
  }) async {
    final body = bodyParams ?? {};
    final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
    final headerParams = <String, String>{
      'timestamp':  timestamp,
      'version':    _appVersion,
      'OSVersion':  _osVersion,
      'clientKey':  appKey,
      'clientType': _clientType,
    };
    if (token != null) headerParams['token'] = token;

    final sign = _generateSign(body, headerParams, appSecret);

    final headers = <String, String>{
      ...headerParams,
      'appId':        _appId,
      'language':     _language,
      'gaid':         _gaid,
      'androidId':    _androidId,
      'sign':         sign,
      'Content-Type': 'application/json',
    };

    final url = Uri.parse('$_baseUrl$endpoint');
    try {
      http.Response resp;
      if (method.toUpperCase() == 'GET') {
        final getUrl = url.replace(queryParameters:
            body.map((k, v) => MapEntry(k, v.toString())));
        resp = await _client.get(getUrl, headers: headers)
            .timeout(const Duration(seconds: 8));
      } else {
        resp = await _client.post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 8));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'code': -1, 'msg': 'Network/Http Error: $e'};
    }
  }

  // ── Step 1 — Fetch app keys ──────────────────────────────────────
  
  static Future<bool> checkAppUpdate() async {
    try {
      final url = Uri.parse('$_baseUrl/anon/client/checkVersion');
      final resp = await _client.get(url, headers: _baseHeaders());
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['data'] != null) {
        final int forcedUpgrade = data['data']['forcedUpgrade'] as int? ?? 0;
        return forcedUpgrade == 1; // Return true if forcedUpgrade is 1
      }
    } catch (_) {}
    return false;
  }

  static Future<({String key, String secret})?> fetchAppKeys() async {
    try {
      final url = Uri.parse('$_baseUrl/anon/client/checkVersion');
      final resp = await _client.get(url, headers: _baseHeaders());
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['data'] != null) {
        return (
          key:    data['data']['clientKey'] as String,
          secret: data['data']['clientSecret'] as String,
        );
      }
    } catch (_) {}
    return null;
  }

  // ── Step 2 — Fetch captcha image ─────────────────────────────────

  static Future<CaptchaResult?> fetchCaptcha() async {
    try {
      final url  = Uri.parse('$_baseUrl/anon/test/getCaptcha');
      final resp = await _client.get(url);
      final token = resp.headers['captchatoken'] ??
                    resp.headers['captchaToken'] ??
                    resp.headers['CaptchaToken'];
      if (token == null || token.isEmpty) return null;
      return CaptchaResult(token: token, imageBytes: resp.bodyBytes);
    } catch (_) {}
    return null;
  }

  // ── Step 3 — Login with captcha ──────────────────────────────────

  static Future<LoginResult> login({
    required String appKey,
    required String appSecret,
    required String username,
    required String password,
    required String captchaCode,
    required String captchaToken,
  }) async {
    try {
      final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
      final body = {
        'userName':     username,
        'passwd':       password,
        'captcha':      captchaCode,
        'captchaToken': captchaToken,
      };
      final headerParams = {
        'timestamp':  timestamp,
        'version':    _appVersion,
        'OSVersion':  _osVersion,
        'clientKey':  appKey,
        'clientType': _clientType,
      };
      final sign = _generateSign(body, headerParams, appSecret);
      final headers = _baseHeaders(
        clientKey: appKey,
        sign: sign,
        timestamp: timestamp,
      );

      final url  = Uri.parse('$_baseUrl/anon/login');
      final resp = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final code = data['code'];
      if (code == 0 || code == '000000') {
        final token = (data['data'] as Map?)? ['token'] as String?;
        if (token != null && token.isNotEmpty) {
          return LoginResult(success: true, authToken: token);
        }
      }
      final msg = data['msg'] as String? ?? 'Login failed';
      return LoginResult(success: false, errorMessage: msg);
    } catch (e) {
      return LoginResult(success: false, errorMessage: 'Network error: $e');
    }
  }

  // ── Select payment tool ──────────────────────────────────────────

  static Future<({Map<String, dynamic>? tool, String? error})> selectPaymentTool({
    required String appKey,
    required String appSecret,
    required String token,
    String? preferredToolName,
  }) async {
    final res = await apiRequest(
      '/api/tool/mylist',
      bodyParams: {},
      appKey: appKey,
      appSecret: appSecret,
      token: token,
      method: 'GET',
    );
    final code = res?['code'];
    final isSuccess = (code == 0 || code == '000000' || code == '0');
    if (res == null || !isSuccess) {
      return (tool: null, error: res?['msg']?.toString() ?? 'Failed to fetch payment tools.');
    }
    final tools = (res['data'] as List?);
    if (tools == null || tools.isEmpty) {
      return (tool: null, error: 'No payment tools found on account.');
    }
    
    // First try to match the preferred tool if provided
    if (preferredToolName != null && preferredToolName.isNotEmpty) {
      final query = preferredToolName.toLowerCase();
      // If the user selected "Any", don't filter. Let it fall back to Freecharge or the first available.
      if (query != 'any') {
        for (final t in tools) {
          if (t is Map<String, dynamic>) {
            final tName = (t['toolName'] as String? ?? '').toLowerCase();
            if (tName.contains(query)) {
              return (tool: t, error: null);
            }
          }
        }
      }
    }

    // Default: Prefer Freecharge if no matching preferred tool was found
    for (final t in tools) {
      if (t is Map<String, dynamic> &&
          (t['toolName'] as String? ?? '').toLowerCase() == 'freecharge') {
        return (tool: t, error: null);
      }
    }
    return (tool: tools[0] as Map<String, dynamic>, error: null);
  }

  // ── Fetch task list ─────────────────────────────────────────────

  static Future<({List<Map<String, dynamic>> tasks, String? error})> fetchTaskList({
    required String appKey,
    required String appSecret,
    required String token,
    double? minAmount,
    double? maxAmount,
  }) async {
    // NOTE: Do NOT pass minAmount/maxAmount to the server-side filter.
    // The API's server-side filter returns stale/old orders for certain ranges.
    // Instead, fetch ALL available orders and filter client-side (like the Python script).
    final res = await apiRequest(
      '/api/order/grablist',
      bodyParams: {'page': 1, 'size': 50, 'data': {}},
      appKey: appKey,
      appSecret: appSecret,
      token: token,
      method: 'POST',
    );
    if (res == null) return (tasks: <Map<String, dynamic>>[], error: 'Connection failed or timeout');
    final code = res['code'];
    final isSuccess = (code == 0 || code == '000000' || code == '0');
    if (!isSuccess) {
      return (tasks: <Map<String, dynamic>>[], error: res['msg']?.toString() ?? res.toString());
    }
    final data = res['data'];
    List records = [];
    if (data is List) {
      records = data;
    } else if (data is Map && data.containsKey('records')) {
      records = data['records'] as List? ?? [];
    }
    return (
      tasks: records.whereType<Map<String, dynamic>>().toList(),
      error: null
    );
  }

  // ── Initialize a single task ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> initializeTask({
    required String taskId,
    required Map<String, dynamic> selectedTool,
    required String appKey,
    required String appSecret,
    required String token,
  }) async {
    final res = await apiRequest(
      '/api/order/grab',
      bodyParams: {
        'orderId':  taskId,
        'toolType': selectedTool['toolType'],
        'upiAddr':  selectedTool['upiAddr'] ?? selectedTool['account'] ?? selectedTool['toolAccount'],
      },
      appKey: appKey,
      appSecret: appSecret,
      token: token,
      method: 'POST',
    );
    return res;
  }

  // ── Verify a task ─────────────────────────────────────────────

  static Future<Map<String, dynamic>?> verifyTask({
    required String taskId,
    required String appKey,
    required String appSecret,
    required String token,
  }) async {
    return apiRequest(
      '/api/order/machine/review',
      bodyParams: {'orderId': taskId},
      appKey: appKey,
      appSecret: appSecret,
      token: token,
      method: 'POST',
    );
  }
}
