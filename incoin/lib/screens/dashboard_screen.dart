import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/python_service.dart';
import '../services/supabase_service.dart';
import '../widgets/referral_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = const FlutterSecureStorage();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isProcessing = false;
  bool _stopRequested = false;
  double _processProgress = 0.0;
  String _processStatusLine = "";
  List<String> _currentLogs = [];

  // ── Settings (can be exposed to a settings screen later) ──
  double _minComplexity = 100;
  double _maxComplexity = 0;       // 0 = no limit
  int    _targetCount = 3;
  String _preferredToolName = 'Freecharge';

  static bool _hasShownReferralPopup = false;

  @override
  void initState() {
    super.initState();
    _checkReferralEligibility();
  }

  Future<void> _checkReferralEligibility() async {
    if (_hasShownReferralPopup) return;
    
    // Check if the user has already applied for free credits
    final hasApplied = await _supabaseService.checkReferralApplicationStatus();
    if (hasApplied || !mounted) return;

    _hasShownReferralPopup = true;

    // Show the dialog after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showWelcomeReferralPopup();
      }
    });
  }

  void _showWelcomeReferralPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.purple, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to Incoin Assistant!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Share the app with your friends and get 50 FREE feature credits to enhance your workflow!',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openReferralBottomSheet();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Claim 50 Free Credits Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openReferralBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReferralBottomSheet(),
    );
  }

  // ── Task logic ──
  void _startTaskProcessing() async {
    final username = await _storage.read(key: 'incoin_username');
    final password = await _storage.read(key: 'incoin_password');
    final token = await _storage.read(key: 'incoin_token');

    if (!mounted) return;

    if (username == null || password == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect your service workspace first.'),
        ),
      );
      Navigator.of(context).pushNamed('/connect_incoin');
      return;
    }

    // Credit check
    try {
      final balance = await _supabaseService.getCredits();
      if (balance <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient tool credits! Please top up to continue.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking credits: $e');
    }

    setState(() {
      _isProcessing = true;
      _stopRequested = false;
      _processProgress = 0.0;
      _processStatusLine = "Initializing...";
      _currentLogs = [];
    });

    try {
      final stream = PythonService.startTaskProcessing(
        username,
        password,
        minAmount:   _minComplexity,
        maxAmount:   _maxComplexity,
        targetCount: _targetCount,
        token:       token,
        preferredToolName: _preferredToolName,
        stopSignal: () => _stopRequested,
      );

      TaskResult? finalResult;

      await for (final result in stream) {
        if (!mounted) return;
        if (_stopRequested) break;
        // Surface the latest log line (especially errors) as the live message
        final lastLog = result.logs.isNotEmpty ? result.logs.last : null;
        final isError = lastLog != null &&
            (lastLog.startsWith('✗') || lastLog.toLowerCase().contains('error') || lastLog.toLowerCase().contains('fail'));
        setState(() {
          _processProgress = result.progress;
          _processStatusLine = isError ? lastLog! : result.message;
          _currentLogs = result.logs;
        });
        finalResult = result;
      }

      if (!mounted || finalResult == null) return;
      final result = finalResult;

      if (result.processed > 0) {
        await _supabaseService.addTaskLog(
          tasksCount: result.processed,
          creditsUsed: 1, 
        );
      }

      _showTaskResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() {
        _isProcessing = false;
        _processProgress = 0.0;
        _processStatusLine = "";
      });
    }
  }

  void _showTaskResultDialog(TaskResult result) {
    final isDailyLimit = result.logs.any((l) =>
        l.toLowerCase().contains('daily limit') ||
        l.toLowerCase().contains('come back tomorrow') ||
        l.toLowerCase().contains('reach max') ||
        l.toLowerCase().contains('maximum limit'));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.success ? 'Process Complete' : 'Process Incomplete',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDailyLimit) ...[
                _buildTroubleshootStep(Icons.wifi, 'Check your internet speed'),
                const SizedBox(height: 10),
                _buildTroubleshootStepWithAction(
                  Icons.hub_rounded,
                  'Check tool connection',
                  'Relink',
                  () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushNamed('/connect_incoin');
                  },
                ),
                const SizedBox(height: 10),
                _buildTroubleshootStep(Icons.schedule_rounded, 'Try after some time'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'If this message keeps appearing, your daily limit has been reached. Try again tomorrow.',
                          style: TextStyle(fontSize: 13, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  !result.success && result.logs.isNotEmpty
                      ? (result.logs.lastWhere(
                          (l) => l.startsWith('✗') || l.toLowerCase().contains('fail'),
                          orElse: () => result.message,
                        ))
                      : result.message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.success ? null : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                if (result.success && result.processedTasks.isNotEmpty) ...[
                  const Text('Processed Tasks:', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: result.processedTasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = result.processedTasks[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          title: Text('Task ID: ${task['taskId']}'),
                          trailing: const Text(
                            'Successful',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final minCtrl = TextEditingController(text: _minComplexity.toStringAsFixed(0));
    final maxCtrl = TextEditingController(
        text: _maxComplexity == 0 ? '' : _maxComplexity.toStringAsFixed(0));
    final cntCtrl = TextEditingController(text: '$_targetCount');
    String localPreferredTool = _preferredToolName;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Workflow Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Min Complexity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Complexity (blank = any)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cntCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tasks per Run',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: localPreferredTool,
              decoration: const InputDecoration(
                labelText: 'Preferred Connector',
                border: OutlineInputBorder(),
              ),
              items: ['Freecharge', 'Mobikwik', 'Amazon pay', 'Any'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t));
              }).toList(),
              onChanged: (val) {
                if (val != null) localPreferredTool = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _minComplexity   = double.tryParse(minCtrl.text) ?? _minComplexity;
                _maxComplexity   = double.tryParse(maxCtrl.text) ?? 0;
                _targetCount = int.tryParse(cntCtrl.text) ?? _targetCount;
                _preferredToolName = localPreferredTool;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Incoin Assistant',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? Colors.white : Colors.black87),
            tooltip: 'Workflow Settings',
            onPressed: _showSettingsDialog,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.info_outline_rounded,
                color: isDark ? Colors.white : Colors.black87),
            tooltip: 'Info',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (route) => Navigator.of(context).pushNamed(route),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '/about',
                  child: Row(children: [Text('ℹ️  '), Text('About')])),
              PopupMenuItem(value: '/contact',
                  child: Row(children: [Text('📧  '), Text('Contact Us')])),
              PopupMenuDivider(),
              PopupMenuItem(value: '/terms',
                  child: Row(children: [Text('📄  '), Text('Terms & Conditions')])),
              PopupMenuItem(value: '/privacy',
                  child: Row(children: [Text('🔒  '), Text('Privacy Policy')])),
              PopupMenuItem(value: '/refund',
                  child: Row(children: [Text('💳  '), Text('Refund Policy')])),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout, color: isDark ? Colors.white : Colors.black87),
            tooltip: 'Sign Out',
            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF141E30), const Color(0xFF243B55)]
                : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome
                const Text(
                  'Work securely 👋',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        'Complexity: ${_minComplexity.toStringAsFixed(0)}'
                        ' – ${_maxComplexity == 0 ? "Any" : _maxComplexity.toStringAsFixed(0)}'
                        '  •  $_targetCount tasks/run',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabaseService.creditsStream,
                        builder: (context, snapshot) {
                          final dynamic rawBalance = snapshot.hasData && snapshot.data!.isNotEmpty 
                              ? snapshot.data!.first['balance'] 
                              : 0;
                          final int credits = rawBalance is int ? rawBalance : (rawBalance as num?)?.toInt() ?? 0;
                          
                          return _buildStatCard(
                            context,
                            title: 'Credits',
                            value: '$credits',
                            icon: Icons.auto_fix_high_rounded,
                            color: const Color(0xFFFFA000),
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: _supabaseService.totalTasksStream,
                        builder: (context, snapshot) {
                          final total = snapshot.data ?? 0;
                          return _buildStatCard(
                            context,
                            title: 'Daily Tasks',
                            value: '$total',
                            icon: Icons.assignment_turned_in_rounded,
                            color: const Color(0xFF00C853),
                          );
                        }
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action buttons
                _buildActionButton(
                  context,
                  title: _isProcessing
                      ? (_stopRequested ? 'Stopping...' : 'Stop Processing')
                      : 'Start Task Processing',
                  subtitle: _isProcessing
                      ? 'Tap to cancel the process'
                      : 'Run $_targetCount assisted actions',
                  icon: _isProcessing ? Icons.stop_circle_rounded : Icons.bolt_rounded,
                  color: _isProcessing ? const Color(0xFFD32F2F) : const Color(0xFF6200EA),
                  isPrimary: true,
                  isLoading: _isProcessing,
                  progress: _processProgress,
                  onTap: _isProcessing
                      ? () => setState(() => _stopRequested = true)
                      : _startTaskProcessing,
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  _buildCreativeLoadingWidget(),
                ],
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'Top Up Credits',
                  subtitle: 'Enable utility features',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF2979FF),
                  onTap: () => Navigator.of(context).pushNamed('/buy_credits'),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'Activity History',
                  subtitle: 'View task processing logs',
                  icon: Icons.history_rounded,
                  color: const Color(0xFF00BFA5),
                  onTap: () => Navigator.of(context).pushNamed('/order_logs'),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'Workspace Link',
                  subtitle: 'Update connection credentials',
                  icon: Icons.hub_rounded,
                  color: const Color(0xFFFF3D00),
                  onTap: () => Navigator.of(context).pushNamed('/connect_incoin'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTroubleshootStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildTroubleshootStepWithAction(
      IconData icon, String text, String actionLabel, VoidCallback onTap) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreativeLoadingWidget() {
    final isError = _processStatusLine.startsWith('✗') ||
        _processStatusLine.toLowerCase().contains('error') ||
        _processStatusLine.toLowerCase().contains('fail') ||
        _processStatusLine.toLowerCase().contains('limit');
    final color = isError ? Colors.redAccent : Colors.purpleAccent;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(_processStatusLine),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withOpacity(0.08)
              : Colors.purple.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            isError
                ? Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20)
                : SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.purpleAccent,
                    ),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _processStatusLine.isEmpty ? 'Initializing...' : _processStatusLine,
                style: TextStyle(
                  color: isError ? Colors.redAccent : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.1 : 0.6)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
    double progress = 0.0,
    bool isPrimary = false,
  }) {
    final disabled = onTap == null && !isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPrimary 
            ? null 
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7)),
        gradient: isPrimary
            ? LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPrimary 
              ? Colors.white.withOpacity(0.2) 
              : Colors.white.withOpacity(isDark ? 0.1 : 0.6)
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary ? color.withOpacity(0.4) : Colors.black.withOpacity(0.03),
            blurRadius: isPrimary ? 24 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white.withOpacity(0.25) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isLoading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress / 100 : null,
                      strokeWidth: 3,
                      color: isPrimary ? Colors.white : color,
                    ),
                  )
                : Icon(icon, color: isPrimary ? Colors.white : color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isPrimary ? Colors.white.withOpacity(0.8) : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded, 
            color: isPrimary ? Colors.white70 : Colors.grey
          ),
        ],
      ),
    );

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}

