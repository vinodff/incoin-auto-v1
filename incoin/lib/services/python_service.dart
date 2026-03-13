import 'dart:convert';
import 'incoin_api_service.dart';

class GrabResult {
  final bool success;
  final String message;
  final List<String> logs;
  final int confirmed;
  final double progress;
  final List<Map<String, dynamic>> confirmedOrders;

  GrabResult({
    required this.success,
    required this.message,
    required this.logs,
    required this.confirmed,
    this.progress = 0.0,
    this.confirmedOrders = const [],
  });

  factory GrabResult.fromJson(Map<String, dynamic> json) {
    return GrabResult(
      success:   json['success'] as bool? ?? false,
      message:   json['message'] as String? ?? '',
      logs:      List<String>.from(json['logs'] as List? ?? []),
      confirmed: json['confirmed'] as int? ?? 0,
      progress:  (json['progress'] as num?)?.toDouble() ?? 0.0,
      confirmedOrders: List<Map<String, dynamic>>.from(json['confirmedOrders'] as List? ?? []),
    );
  }
}

class PythonService {
  /// Start the order grabbing – pure Dart, works on all platforms (web, Android, etc.)
  ///
  /// [username]    – Incoin account username / phone number
  /// [password]    – Incoin account password
  /// [minAmount]   – minimum order amount to grab (default 101)
  /// [maxAmount]   – maximum order amount to grab (0 = no limit)
  /// [targetCount] – number of orders to grab and confirm (default 3)
  ///
  /// Returns a [Stream<GrabResult>] yielding progress updates and the final outcome.
  static Stream<GrabResult> startOrderGrab(
    String username,
    String password, {
    double minAmount   = 101,
    double maxAmount   = 0,       // 0 means unlimited
    int    targetCount = 3,
    String? token,                // Optional saved token
  }) async* {
    final logs = <String>[];

    try {
      // ── Step 1: Fetch app keys ──────────────────────────────────
      logs.add('Fetching app keys...');
      yield GrabResult(success: false, message: 'Starting...', logs: List.from(logs), confirmed: 0, progress: 5);
      final keys = await IncoinApiService.fetchAppKeys();
      if (keys == null) {
        yield GrabResult(
          success: false,
          message: 'Could not fetch app keys. Check internet connection.',
          logs: logs,
          confirmed: 0,
          progress: 0,
        );
        return;
      }
      final appKey    = keys.key;
      final appSecret = keys.secret;
      logs.add('App key obtained.');
      yield GrabResult(success: false, message: 'Authenticating...', logs: List.from(logs), confirmed: 0, progress: 10);

      // ── Step 2: Login ───────────────────────────────────────────
      String activeToken;
      if (token != null && token.isNotEmpty) {
        logs.add('Using saved authentication token.');
        activeToken = token;
      } else {
        logs.add('Logging in...');
        final captcha = await IncoinApiService.fetchCaptcha();
        final captchaToken = captcha?.token ?? '';

        final loginResult = await IncoinApiService.login(
          appKey: appKey,
          appSecret: appSecret,
          username: username,
          password: password,
          captchaCode: '',
          captchaToken: captchaToken,
        );

        if (!loginResult.success || loginResult.authToken == null) {
          yield GrabResult(
            success: false,
            message: loginResult.errorMessage ?? 'Login failed. Check your Incoin credentials.',
            logs: logs,
            confirmed: 0,
            progress: 0,
          );
          return;
        }
        activeToken = loginResult.authToken!;
        logs.add('Login successful.');
      }
      yield GrabResult(success: false, message: 'Preparing order grab...', logs: List.from(logs), confirmed: 0, progress: 20);

      // ── Step 3: Select payment tool ─────────────────────────────
      logs.add('Fetching payment tools...');
      final toolResult = await IncoinApiService.selectPaymentTool(
        appKey: appKey,
        appSecret: appSecret,
        token: activeToken,
      );
      if (toolResult.tool == null) {
        yield GrabResult(
          success: false,
          message: toolResult.error ?? 'No payment tool available.',
          logs: logs,
          confirmed: 0,
          progress: 0,
        );
        return;
      }
      final selectedTool = toolResult.tool!;
      logs.add('Using tool: ${selectedTool['toolName']}');
      yield GrabResult(success: false, message: 'Scanning for orders...', logs: List.from(logs), confirmed: 0, progress: 30);

      // ── Step 4: Grab & confirm orders ───────────────────────────
      final effectiveMax = maxAmount == 0 ? double.infinity : maxAmount;
      logs.add('Scanning for orders (₹${minAmount.toStringAsFixed(0)} – '
               '${effectiveMax.isInfinite ? "Any" : effectiveMax.toStringAsFixed(0)})...');

      final grabbedOrders = <Map<String, dynamic>>[];
      const maxPollIterations = 300;
      var stopFlag = false;

      for (var i = 0; i < maxPollIterations && grabbedOrders.length < targetCount && !stopFlag; i++) {
        final records = await IncoinApiService.fetchOrderList(
          appKey: appKey,
          appSecret: appSecret,
          token: activeToken,
        );

        if (records.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 50));
          continue;
        }

        // Filter matching orders
        final grabbedIds = grabbedOrders.map((o) => o['id']).toSet();
        final ordersToGrab = <Map<String, dynamic>>[];

        for (final order in records) {
          final orderId = order['orderId'];
          final amount  = (order['amount'] as num?)?.toDouble() ?? 0;
          if (orderId == null) continue;
          if (amount < minAmount || amount > effectiveMax) continue;
          if (grabbedIds.contains(orderId)) continue;
          ordersToGrab.add({'id': orderId, 'amount': amount});
          if (ordersToGrab.length >= 10) break;
        }

        if (ordersToGrab.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 50));
          continue;
        }

        logs.add('Found ${ordersToGrab.length} matching order(s)! Grabbing and confirming...');

        // ── Concurrent grab & immediate parallel confirmation ──────────
        final grabAndConfirmFutures = ordersToGrab.map((o) async {
          final grabRes = await IncoinApiService.grabOrder(
            orderId: o['id'] as String,
            selectedTool: selectedTool,
            appKey: appKey,
            appSecret: appSecret,
            token: activeToken,
          );
          
          if (grabRes != null && (grabRes['code'] == 0 || grabRes['code'] == '000000')) {
            var realId = o['id'];
            if (grabRes['data'] is Map && grabRes['data']['orderId'] != null) {
              realId = grabRes['data']['orderId'];
            }
            
            // Confirm immediately!
            final confirmRes = await IncoinApiService.confirmOrder(
              orderId: realId as String,
              appKey: appKey,
              appSecret: appSecret,
              token: activeToken,
            );
            
            return {'id': realId, 'amount': o['amount'], 'grabbed': true, 'confirmed': (confirmRes != null && (confirmRes['code'] == 0 || confirmRes['code'] == '000000'))};
          }
          return {'id': o['id'], 'amount': o['amount'], 'grabbed': false, 'confirmed': false, 'msg': grabRes?['msg']};
        }).toList();

        final results = await Future.wait(grabAndConfirmFutures);

        for (final r in results) {
          final oid = r['id'];
          final amt = r['amount'];
          final grabbed = r['grabbed'] as bool;
          final confirmed = r['confirmed'] as bool;

          if (grabbed) {
            logs.add('✓ Grabbed order $oid (₹$amt)');
            if (confirmed) {
              logs.add('  ✓ Successfully confirmed!');
              if (!grabbedOrders.any((o) => o['id'] == oid)) {
                grabbedOrders.add({'id': oid, 'amount': amt, 'confirmed': true});
              }
            } else {
              logs.add('  ✗ Confirmation failed.');
            }
          } else {
            final msg = r['msg'] ?? 'Unknown error';
            logs.add('✗ Missed $oid: $msg');
            if (msg.toString().toLowerCase().contains('reach max count')) {
              logs.add('Max grab count reached. Stopping.');
              stopFlag = true;
            }
          }
        }
        
        final successfulCount = grabbedOrders.where((o) => o['confirmed'] == true).length;
        final progressPct = (30 + ((successfulCount / targetCount) * 70).clamp(0, 70)).toDouble();
        yield GrabResult(success: false, message: 'Grabbing orders ($successfulCount/$targetCount)...', logs: List.from(logs), confirmed: successfulCount, progress: progressPct);

        if (successfulCount >= targetCount) break;
      }

      final successfulOrders = grabbedOrders.where((o) => o['confirmed'] == true).map((o) => {'orderId': o['id'], 'amount': o['amount']}).toList();
      final finalConfirmedCount = successfulOrders.length;

      final msg = finalConfirmedCount > 0
          ? 'Done! Successfully confirmed $finalConfirmedCount/$targetCount orders.'
          : 'No orders were confirmed. The platform may have no orders right now.';

      yield GrabResult(
        success: finalConfirmedCount > 0,
        message: msg,
        logs: logs,
        confirmed: finalConfirmedCount,
        progress: 100,
        confirmedOrders: successfulOrders,
      );

    } catch (e) {
      logs.add('Unexpected error: $e');
      yield GrabResult(
        success: false,
        message: 'Script crashed: $e',
        logs: logs,
        confirmed: 0,
        progress: 0,
      );
    }
  }
}
