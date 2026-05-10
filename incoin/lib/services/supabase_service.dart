import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final _supabase = Supabase.instance.client;

  // Auth getters
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Authentication
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String state,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'state': state,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Credits
  Stream<List<Map<String, dynamic>>> get creditsStream {
    if (!isAuthenticated) return Stream.value([]);
    return _supabase
        .from('user_credits')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', currentUser!.id);
  }

  Future<int> getCredits() async {
    if (!isAuthenticated) return 0;
    final res = await _supabase
        .from('user_credits')
        .select('balance')
        .eq('user_id', currentUser!.id)
        .single();
    return res['balance'] as int;
  }

  // Logs
  Stream<List<Map<String, dynamic>>> get taskLogsStream {
    if (!isAuthenticated) return Stream.value([]);
    return _supabase
        .from('order_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('created_at');
  }

  Stream<int> get totalTasksStream {
    if (!isAuthenticated) return Stream.value(0);
    return _supabase
        .from('order_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .map((logs) {
          try {
            return logs.fold<int>(0, (sum, log) {
              final count = log['orders_count'];
              if (count == null) return sum;
              return sum + (count is int ? count : int.tryParse(count.toString()) ?? 0);
            });
          } catch (e) {
            debugPrint('Error mapping totalTasksStream: $e');
            return 0;
          }
        });
  }

  Future<void> addTaskLog({
    required int tasksCount,
    required int creditsUsed,
  }) async {
    if (!isAuthenticated) return;
    
    // Call the RPC for atomic deduction and logging
    await _supabase.rpc('record_order_grab', params: {
      'p_orders_count': tasksCount,
      'p_credits_used': creditsUsed,
    });
  }

  Future<void> addCredits(int amount) async {
    if (!isAuthenticated) {
      debugPrint('addCredits failed: Not authenticated');
      return;
    }
    
    debugPrint('Calling RPC add_credits for ${currentUser!.id} with amount: $amount');
    try {
      await _supabase.rpc('add_credits', params: {
        'p_amount': amount,
      });
      debugPrint('RPC add_credits successful');
    } catch (e) {
      debugPrint('RPC add_credits failed: $e');
      rethrow;
    }
  }

  // Storage
  Future<String> uploadReferralScreenshot(Uint8List fileBytes, String fileName) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    
    final String path = '${currentUser!.id}/$fileName';
    
    await _supabase.storage.from('referral_screenshots').uploadBinary(
      path,
      fileBytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    
    return _supabase.storage.from('referral_screenshots').getPublicUrl(path);
  }

  Future<void> submitReferralApplication(List<String> screenshotUrls) async {
    if (!isAuthenticated) throw Exception('Not authenticated');

    await _supabase.from('referral_applications').insert({
      'user_id': currentUser!.id,
      'image_urls': screenshotUrls,
      'status': 'pending',
    });
  }

  Future<bool> checkReferralApplicationStatus() async {
    if (!isAuthenticated) return false;

    try {
      final response = await _supabase
          .from('referral_applications')
          .select('id')
          .eq('user_id', currentUser!.id)
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking referral status: $e');
      return false;
    }
  }

  // Device registration (prevent multiple accounts per device)
  Future<bool> isDeviceRegistered(String deviceId) async {
    try {
      final response = await _supabase
          .from('device_registrations')
          .select('id')
          .eq('device_id', deviceId)
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking device registration: $e');
      return false;
    }
  }

  Future<void> registerDevice(String deviceId) async {
    if (!isAuthenticated) return;
    try {
      await _supabase.from('device_registrations').insert({
        'device_id': deviceId,
        'user_id': currentUser!.id,
      });
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }
}
