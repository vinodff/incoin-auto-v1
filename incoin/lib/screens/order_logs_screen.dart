import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class OrderLogsScreen extends StatelessWidget {
  const OrderLogsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SupabaseService _supabaseService = SupabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // List Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Date & Time',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Orders',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Credits',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            
            // List Content
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabaseService.orderLogsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('No history found'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final createdAt = DateTime.parse(log['created_at']);
                      final dateStr = DateFormat('dd MMM').format(createdAt);
                      final timeStr = DateFormat('hh:mm a').format(createdAt);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Date & Time
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Orders Confirmed
                          Expanded(
                            flex: 1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  log['orders_count'].toString(),
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          
                          // Credits Used
                          Expanded(
                            flex: 1,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '-${log['credits_used']}',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
