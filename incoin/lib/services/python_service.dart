import 'dart:convert';
import 'incoin_api_service.dart';

class TaskResult {
  final bool success;
  final String message;
  final List<String> logs;
  final int processed;
  final double progress;
  final List<Map<String, dynamic>> processedTasks;

  TaskResult({
    required this.success,
    required this.message,
    required this.logs,
    required this.processed,
    this.progress = 0.0,
    this.processedTasks = const [],
  });

  factory TaskResult.fromJson(Map<String, dynamic> json) {
    return TaskResult(
      success:   json['success'] as bool? ?? false,
      message:   json['message'] as String? ?? '',
      logs:      List<String>.from(json['logs'] as List? ?? []),
      processed: json['processed'] as int? ?? 0,
      progress:  (json['progress'] as num?)?.toDouble() ?? 0.0,
      processedTasks: List<Map<String, dynamic>>.from(json['processedTasks'] as List? ?? []),
    );
  }
}

class PythonService {
  /// Start the task processing – pure Dart, works on all platforms (web, Android, etc.)
  ///
  /// Mirrors the Python script's proven approach:
  ///   • NO stale/date filtering – grab everything the API returns
  ///   • NO blacklisting claimed orders – they may reappear fresh on the next poll
  ///   • Up to 10 concurrent grabs for maximum speed
  ///   • Minimal delays (50-100ms) between polls
  ///
  /// [username]    – Incoin account username / phone number
  /// [password]    – Incoin account password
  /// [minAmount]   – minimum complexity to process
  /// [maxAmount]   – maximum complexity to process (0 = no limit)
  /// [targetCount] – number of tasks to process (default 3)
  ///
  /// Returns a [Stream<TaskResult>] yielding progress updates and the final outcome.
  static Stream<TaskResult> startTaskProcessing(
    String username,
    String password, {
    double minAmount   = 100,
    double maxAmount   = 0,       // 0 means unlimited
    int    targetCount = 3,
    String? token,                // Optional saved token
    String? preferredToolName,    // Optional user-selected tool
    bool Function()? stopSignal,  // Returns true when user requests stop
  }) async* {
    final logs = <String>[];

    try {
      // ── Step 1: Fetch app keys ──────────────────────────────────
      logs.add('Initializing engine...');
      yield TaskResult(success: false, message: 'Starting...', logs: List.from(logs), processed: 0, progress: 5);
      final keys = await IncoinApiService.fetchAppKeys();
      if (keys == null) {
        yield TaskResult(
          success: false,
          message: 'Initialization failed. Check connection.',
          logs: logs,
          processed: 0,
          progress: 0,
        );
        return;
      }
      final appKey    = keys.key;
      final appSecret = keys.secret;
      logs.add('Engine initialized.');
      yield TaskResult(success: false, message: 'Authenticating...', logs: List.from(logs), processed: 0, progress: 10);

      // ── Step 2: Login ───────────────────────────────────────────
      String activeToken;
      if (token != null && token.isNotEmpty) {
        logs.add('Using active session.');
        activeToken = token;
      } else {
        logs.add('Authenticating session...');
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
          yield TaskResult(
            success: false,
            message: loginResult.errorMessage ?? 'Authentication failed.',
            logs: logs,
            processed: 0,
            progress: 0,
          );
          return;
        }
        activeToken = loginResult.authToken!;
        logs.add('Authentication successful.');
      }
      yield TaskResult(success: false, message: 'Preparing tasks...', logs: List.from(logs), processed: 0, progress: 20);

      // ── Step 3: Select payment tool ─────────────────────────────
      logs.add('Configuring connectors...');
      final toolResult = await IncoinApiService.selectPaymentTool(
        appKey: appKey,
        appSecret: appSecret,
        token: activeToken,
        preferredToolName: preferredToolName,
      );
      if (toolResult.tool == null) {
        yield TaskResult(
          success: false,
          message: toolResult.error ?? 'Connector configuration failed.',
          logs: logs,
          processed: 0,
          progress: 0,
        );
        return;
      }
      final selectedTool = toolResult.tool!;
      logs.add('Connector set: ${selectedTool['toolName']}');
      yield TaskResult(success: false, message: 'Scanning for tasks...', logs: List.from(logs), processed: 0, progress: 30);

      // ── Step 4: FAST task processing (matches Python script) ────
      final effectiveMax = maxAmount == 0 ? double.infinity : maxAmount;
      logs.add('⚡ Fast-scan mode (Complexity $minAmount – '
               '${effectiveMax.isInfinite ? "Any" : effectiveMax.toStringAsFixed(0)})');

      final processedJobs = <Map<String, dynamic>>[];
      final permanentlyFailedIds = <String>{};
      var stopFlag = false;
      var listErrorCount = 0;
      var iteration = 0;

      // ═══════════════════════════════════════════════════════════
      // FAST POLLING LOOP — matches Python script behavior exactly
      // • No stale filter, no blacklist for claimed orders
      // • Up to 10 concurrent grabs per batch
      // • 50-100ms polling delays (blazing fast)
      // ═══════════════════════════════════════════════════════════
      while (processedJobs.length < targetCount && !stopFlag && !(stopSignal?.call() ?? false)) {
        iteration++;

        final listResult = await IncoinApiService.fetchTaskList(
          appKey: appKey,
          appSecret: appSecret,
          token: activeToken,
        );

        final records = listResult.tasks;

        // ── Handle API errors ──
        if (listResult.error != null) {
          listErrorCount++;
          final errMsg = listResult.error ?? '';
          final isRateLimited = errMsg.toLowerCase().contains('too many request');

          if (listErrorCount % 10 == 1 || isRateLimited) {
            logs.add('⟳ API busy, retrying... ($errMsg)');
            yield TaskResult(
              success: false,
              message: 'Scanning... (${processedJobs.length}/$targetCount)',
              logs: List.from(logs),
              processed: processedJobs.length,
              progress: 30 + (processedJobs.length / targetCount * 60),
            );
          }
          if (listErrorCount >= 50) {
            logs.add('✗ Too many consecutive errors. Stopping.');
            stopFlag = true;
            break;
          }
          await Future.delayed(Duration(milliseconds: isRateLimited ? 3000 : 100));
          continue;
        }
        listErrorCount = 0;

        // ── Empty result — instant retry ──
        if (records.isEmpty) {
          await Future.delayed(Duration.zero);
          continue;
        }

        // ── Filter tasks (client-side, like Python script) ──
        // NO stale filter, NO blacklist — just range check and already-processed check.
        final processedIds = processedJobs.map((o) => o['id']).toSet();
        final tasksToProcess = <Map<String, dynamic>>[];
        int outOfRangeCount = 0;

        for (final item in records) {
          final taskId = item['orderId'];
          final amountVal = item['amount'];
          final complexity = double.tryParse(amountVal?.toString() ?? '') ?? 0.0;

          if (taskId == null) continue;
          if (processedIds.contains(taskId)) continue;
          if (permanentlyFailedIds.contains(taskId)) continue;

          // Client-side range check
          if (complexity < minAmount || (effectiveMax.isFinite && complexity > effectiveMax)) {
            outOfRangeCount++;
            continue;
          }

          tasksToProcess.add({'id': taskId, 'complexity': complexity});
          if (tasksToProcess.length >= 20) break; // 20 concurrent grabs for maximum speed
        }

        // ── No matching tasks — fast retry ──
        if (tasksToProcess.isEmpty) {
          if (iteration % 20 == 1) {
            final rangeInfo = effectiveMax.isInfinite
                ? '≥${minAmount.toStringAsFixed(0)}'
                : '${minAmount.toStringAsFixed(0)}–${effectiveMax.toStringAsFixed(0)}';
            final detail = records.isEmpty
                ? 'No tasks in queue yet'
                : 'Found ${records.length} task(s), $outOfRangeCount out-of-range for $rangeInfo';
            logs.add('⟳ $detail. Scanning...');
            yield TaskResult(
              success: false,
              message: 'Scanning (${processedJobs.length}/$targetCount) – $detail',
              logs: List.from(logs),
              processed: processedJobs.length,
              progress: 30 + (processedJobs.length / targetCount * 60),
            );
          }
          await Future.delayed(Duration.zero);
          continue;
        }

        // ── GRAB: Concurrent initialization + immediate verification ──
        logs.add('⚡ Found ${tasksToProcess.length} eligible action(s)! Grabbing...');
        yield TaskResult(
          success: false,
          message: 'Grabbing ${tasksToProcess.length} task(s)...',
          logs: List.from(logs),
          processed: processedJobs.length,
          progress: 30 + (processedJobs.length / targetCount * 60),
        );

        final processFutures = tasksToProcess.map((item) async {
          final initRes = await IncoinApiService.initializeTask(
            taskId: item['id'] as String,
            selectedTool: selectedTool,
            appKey: appKey,
            appSecret: appSecret,
            token: activeToken,
          );

          if (initRes != null && (initRes['code'] == 0 || initRes['code'] == '000000')) {
            var realId = item['id'];
            if (initRes['data'] is Map && initRes['data']['orderId'] != null) {
              realId = initRes['data']['orderId'];
            }

            // Verify immediately!
            final verifyRes = await IncoinApiService.verifyTask(
              taskId: realId as String,
              appKey: appKey,
              appSecret: appSecret,
              token: activeToken,
            );

            return {
              'id': realId,
              'complexity': item['complexity'],
              'initialized': true,
              'verified': (verifyRes != null && (verifyRes['code'] == 0 || verifyRes['code'] == '000000')),
            };
          }

          final failMsg = initRes?['msg']?.toString().toLowerCase() ?? '';
          if (failMsg.contains('reach max') || failMsg.contains('daily limit') || failMsg.contains('maximum limit') || failMsg.contains('cancellation/timeout')) {
            permanentlyFailedIds.add(item['id'] as String);
          }
          final fallbackMsg = initRes != null
              ? (initRes['msg'] ?? initRes['message'] ?? 'Code: ${initRes['code']}')
              : 'Link error';
          return {
            'id': item['id'],
            'complexity': item['complexity'],
            'initialized': false,
            'verified': false,
            'msg': fallbackMsg,
          };
        }).toList();

        final results = await Future.wait(processFutures);

        // ── Process results ──
        for (final r in results) {
          final oid = r['id'];
          final initialized = r['initialized'] as bool;
          final verified = r['verified'] as bool;

          if (initialized) {
            logs.add('✓ Grabbed $oid (₹${r['complexity']})');
            if (verified) {
              logs.add('  ✓ Verified!');
              if (!processedJobs.any((o) => o['id'] == oid)) {
                processedJobs.add({'id': oid, 'verified': true});
              }
            } else {
              logs.add('  ✗ Verification failed.');
            }
          } else {
            final msg = r['msg']?.toString() ?? 'Sync collision';
            final msgLower = msg.toLowerCase();

            if (msgLower.contains('reach max') || msgLower.contains('daily limit') || msgLower.contains('maximum limit') || msgLower.contains('cancellation/timeout')) {
              logs.add('✗ Daily limit reached. Come back tomorrow!');
              stopFlag = true;
            } else {
              // Competition miss or other transient error —
              // do NOT blacklist (Python script doesn't either).
              // Just log and immediately retry on next poll.
              logs.add('✗ $oid: $msg');
            }
          }
        }

        final successfulCount = processedJobs.where((o) => o['verified'] == true).length;
        final progressPct = (30 + ((successfulCount / targetCount) * 70).clamp(0, 70)).toDouble();
        yield TaskResult(
          success: false,
          message: 'Processing ($successfulCount/$targetCount)...',
          logs: List.from(logs),
          processed: successfulCount,
          progress: progressPct,
        );

        if (successfulCount >= targetCount) break;

        // Yield to event loop only — no artificial delay
        await Future.delayed(Duration.zero);
      }

      // ── Final result ──
      final successfulTasks = processedJobs.where((o) => o['verified'] == true).map((o) => {'taskId': o['id']}).toList();
      final finalProcessedCount = successfulTasks.length;

      final msg = finalProcessedCount > 0
          ? 'Done! Successfully processed $finalProcessedCount/$targetCount actions.'
          : 'No actions were processed at this time.';

      yield TaskResult(
        success: finalProcessedCount > 0,
        message: msg,
        logs: logs,
        processed: finalProcessedCount,
        progress: 100,
        processedTasks: successfulTasks,
      );

    } catch (e) {
      logs.add('Technical error: $e');
      yield TaskResult(
        success: false,
        message: 'Process interrupted.',
        logs: logs,
        processed: 0,
        progress: 0,
      );
    }
  }
}
