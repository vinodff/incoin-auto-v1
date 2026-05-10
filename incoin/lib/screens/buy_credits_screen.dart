import 'package:flutter/material.dart';
import '../utils/cashfree_mobile.dart'
    if (dart.library.js) '../utils/cashfree_web.dart';
import '../utils/cashfree_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/referral_bottom_sheet.dart';

class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({Key? key}) : super(key: key);

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isPaymentLoading = false;

  final List<CreditPackage> _packages = [
    CreditPackage(id: 'pkg_100', baseCredits: 50, extraCredits: 5, price: 100, label: 'Starter'),
    CreditPackage(id: 'pkg_200', baseCredits: 100, extraCredits: 15, price: 200, label: 'Popular'),
    CreditPackage(id: 'pkg_500', baseCredits: 300, extraCredits: 25, price: 500, label: 'Value'),
    CreditPackage(id: 'pkg_5000', baseCredits: 5000, extraCredits: 500, price: 5000, label: 'Limited Time!', isHighlighted: true),
  ];

  CreditPackage? _selectedPackage;
  bool _hasAppliedForReferral = false;
  bool _isLoadingReferralStatus = true;

  @override
  void initState() {
    super.initState();
    _selectedPackage = _packages[0];
    _checkReferralStatus();
  }

  Future<void> _checkReferralStatus() async {
    final status = await _supabaseService.checkReferralApplicationStatus();
    if (mounted) {
      setState(() {
        _hasAppliedForReferral = status;
        _isLoadingReferralStatus = false;
      });
    }
  }

  Future<void> _finalizeCredits(int credits) async {
    try {
      await _supabaseService.addCredits(credits);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Credits added.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating credits: $e')),
        );
      }
    }
  }

  Future<void> _startPayment() async {
    if (_selectedPackage == null || _isPaymentLoading) return;

    setState(() => _isPaymentLoading = true);

    final userEmail = _supabaseService.currentUser?.email ?? '';

    try {
      final sessionId = await CashfreeService.createOrder(
        amountInRupees: _selectedPackage!.price,
        customerEmail: userEmail,
      );

      if (!mounted) return;

      await CashfreeWeb.openCheckout(
        paymentSessionId: sessionId,
        onSuccess: () => _finalizeCredits(_selectedPackage!.totalCredits),
        onFailure: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment failed: $msg'), backgroundColor: Colors.red),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaymentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Credits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  final pkg = _packages[index];
                  final isSelected = _selectedPackage?.id == pkg.id;
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPackage = pkg),
                    child: Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue.withOpacity(0.1) 
                                : (pkg.isHighlighted ? Colors.orange.withOpacity(0.05) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.blue : (pkg.isHighlighted ? Colors.orange : Colors.transparent),
                              width: pkg.isHighlighted && !isSelected ? 1.5 : 2,
                            ),
                            boxShadow: [
                              if (!isSelected)
                                BoxShadow(
                                  color: pkg.isHighlighted ? Colors.orange.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.blue 
                                      : (pkg.isHighlighted ? Colors.orange : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.monetization_on_rounded,
                                  color: isSelected || pkg.isHighlighted ? Colors.white : Colors.amber,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pkg.isHighlighted)
                                      Row(
                                        children: [
                                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            pkg.label,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        pkg.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                  Text(
                                    '${pkg.totalCredits} Credits',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (pkg.extraCredits > 0)
                                    Text(
                                      '+ ${pkg.extraCredits} extra credits',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${pkg.price}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pkg.isHighlighted)
                      Positioned(
                        top: 0,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.orangeAccent, Colors.deepOrange],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'LIMITED OFFER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: InkWell(
                  onTap: _isLoadingReferralStatus ? null : (_hasAppliedForReferral ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You have already applied for free credits!')),
                    );
                  } : _showReferralDialog),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isLoadingReferralStatus 
                            ? [Colors.grey.shade400, Colors.grey.shade600]
                            : (_hasAppliedForReferral 
                                ? [Colors.green.shade400, Colors.green.shade600] 
                                : [Colors.purple.shade400, Colors.deepPurple.shade600]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _hasAppliedForReferral ? Colors.green.withOpacity(0.3) : Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: _isLoadingReferralStatus 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(_hasAppliedForReferral ? Icons.check_circle : Icons.card_giftcard, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLoadingReferralStatus ? 'Loading...' : (_hasAppliedForReferral ? 'You successfully applied for free credits' : 'Free Credits by Referral'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: boldTextStyle,
                                  fontSize: 16,
                                ),
                              ),
                              if (!_hasAppliedForReferral && !_isLoadingReferralStatus)
                                const Text(
                                  'Get 50 free credits',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!_hasAppliedForReferral && !_isLoadingReferralStatus)
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'IMPORTANT DISCLAIMER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Credits are used to access features within the application. They do not represent monetary value and cannot be withdrawn. All purchases are final and non-refundable once used.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: CustomButton(
                  text: _isPaymentLoading ? 'Opening Payment...' : 'Pay ₹${_selectedPackage?.price ?? 0}',
                  onPressed: _isPaymentLoading ? () {} : _startPayment,
                  icon: Icons.payment,
                ),
              ),
            ],
          ),
        ),
      );
    }
  
    // Constant workaround helper
    static const boldTextStyle = FontWeight.bold;
  
    void _showReferralDialog() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReferralBottomSheet(onApplied: _checkReferralStatus),
      );
    }
  }
  


class CreditPackage {
  final String id;
  final int baseCredits;
  final int extraCredits;
  final int price;
  final String label;
  final bool isHighlighted;

  CreditPackage({
    required this.id,
    required this.baseCredits,
    required this.extraCredits,
    required this.price,
    required this.label,
    this.isHighlighted = false,
  });

  int get totalCredits => baseCredits + extraCredits;
}
