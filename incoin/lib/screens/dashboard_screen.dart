import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/python_service.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = const FlutterSecureStorage();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isGrabbing = false;
  double _grabProgress = 0.0;
  String _grabStatusLine = "";

  // ── Settings (can be exposed to a settings screen later) ──
  double _minAmount   = 101;
  double _maxAmount   = 0;       // 0 = no limit
  int    _targetCount = 3;

  // ── Quick stats (update after each grab run) ──
  // No longer needed, using StreamBuilder

  // ─────────────────────────────────────────────
  // Grab logic
  // ─────────────────────────────────────────────
  void _startOrderGrab() async {
    final username = await _storage.read(key: 'incoin_username');
    final password = await _storage.read(key: 'incoin_password');
    final token = await _storage.read(key: 'incoin_token');

    if (!mounted) return;

    if (username == null || password == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect your Incoin account first.'),
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
            content: Text('Insufficient credits! Please buy credits to continue.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      // If we can't fetch credits, we'll assume 0 for safety or handle error
      debugPrint('Error checking credits: $e');
    }

    setState(() {
      _isGrabbing = true;
      _grabProgress = 0.0;
      _grabStatusLine = "Starting...";
    });

    try {
      final stream = PythonService.startOrderGrab(
        username,
        password,
        minAmount:   _minAmount,
        maxAmount:   _maxAmount,
        targetCount: _targetCount,
        token:       token,
      );

      GrabResult? finalResult;

      await for (final result in stream) {
        if (!mounted) return;
        setState(() {
          _grabProgress = result.progress;
          _grabStatusLine = result.message;
        });
        finalResult = result;
      }

      if (!mounted || finalResult == null) return;
      final result = finalResult;

      if (result.confirmed > 0) {
        // Persist to Supabase - the totalOrdersStream will update the UI automatically
        await _supabaseService.addOrderLog(
          ordersCount: result.confirmed,
          creditsUsed: 1, // Logic: 1 processing session uses 1 credit
        );
      }

      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() {
        _isGrabbing = false;
        _grabProgress = 0.0;
        _grabStatusLine = "";
      });
    }
  }

  void _showResultDialog(GrabResult result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                result.success ? 'Success' : 'Failed',
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
              Text(result.message,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (result.success && result.confirmedOrders.isNotEmpty) ...[
                const Text('Confirmed Orders:', style: TextStyle(color: Colors.grey)),
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
                    itemCount: result.confirmedOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = result.confirmedOrders[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        title: Text('Order ID: ${order['orderId']}'),
                        trailing: Text(
                          '₹${order['amount']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (result.logs.isNotEmpty) ...[
                const Text('Log:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: result.logs
                          .map((l) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1),
                                child: Text(l,
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Settings dialog
  // ─────────────────────────────────────────────
  void _showSettingsDialog() {
    final minCtrl = TextEditingController(text: _minAmount.toStringAsFixed(0));
    final maxCtrl = TextEditingController(
        text: _maxAmount == 0 ? '' : _maxAmount.toStringAsFixed(0));
    final cntCtrl = TextEditingController(text: '$_targetCount');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Grab Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Min Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Amount (₹, blank = no limit)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cntCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Orders per Run',
                border: OutlineInputBorder(),
              ),
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
                _minAmount   = double.tryParse(minCtrl.text) ?? _minAmount;
                _maxAmount   = double.tryParse(maxCtrl.text) ?? 0;
                _targetCount = int.tryParse(cntCtrl.text) ?? _targetCount;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Incoin Auto',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white : Colors.black87),
            tooltip: 'Grab Settings',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: isDark ? Colors.white : Colors.black87),
            tooltip: 'Logout',
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
                  'Welcome back 👋',
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
                        '₹${_minAmount.toStringAsFixed(0)}'
                        ' – ${_maxAmount == 0 ? "Any amount" : "₹${_maxAmount.toStringAsFixed(0)}"}'
                        '  •  $_targetCount/run',
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
                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFFFFA000),
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: _supabaseService.totalOrdersStream,
                        builder: (context, snapshot) {
                          final total = snapshot.data ?? 0;
                          return _buildStatCard(
                            context,
                            title: 'Confirmed',
                            value: '$total',
                            icon: Icons.check_circle_rounded,
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
                  title: _isGrabbing ? 'Processing… ${_grabProgress.toStringAsFixed(0)}%' : 'Start Order Grab',
                  subtitle: _isGrabbing
                      ? (_grabStatusLine.isNotEmpty ? _grabStatusLine : 'Auto-grab currently running')
                      : 'Auto-grab & confirm $_targetCount orders',
                  icon: _isGrabbing ? Icons.sync_rounded : Icons.rocket_launch_rounded,
                  color: const Color(0xFF6200EA),     // Deep purple for main action
                  isPrimary: true,
                  isLoading: _isGrabbing,
                  progress: _grabProgress,
                  onTap: _isGrabbing ? null : _startOrderGrab,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'Buy Credits',
                  subtitle: 'Get more via Razorpay',
                  icon: Icons.shopping_bag_rounded,
                  color: const Color(0xFF2979FF),
                  onTap: () => Navigator.of(context).pushNamed('/buy_credits'),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'History',
                  subtitle: 'View your order confirmation logs',
                  icon: Icons.history_rounded,
                  color: const Color(0xFF00BFA5),
                  onTap: () => Navigator.of(context).pushNamed('/order_logs'),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  title: 'Connect Incoin',
                  subtitle: 'Update your Incoin credentials',
                  icon: Icons.link_rounded,
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
