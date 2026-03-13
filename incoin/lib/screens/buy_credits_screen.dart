import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/razorpay_mobile.dart'
    if (dart.library.js) '../utils/razorpay_web.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_button.dart';

class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({Key? key}) : super(key: key);

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  late Razorpay _razorpay;
  final SupabaseService _supabaseService = SupabaseService();
  
  // Live Keys provided by user
  static const String _razorpayKeyId = 'rzp_live_SPyQe1cDlxCPpR';

  final List<CreditPackage> _packages = [
    CreditPackage(id: 'pkg_100', baseCredits: 50, extraCredits: 5, price: 100, label: 'Starter'),
    CreditPackage(id: 'pkg_200', baseCredits: 100, extraCredits: 15, price: 200, label: 'Popular'),
    CreditPackage(id: 'pkg_500', baseCredits: 300, extraCredits: 25, price: 500, label: 'Value'),
  ];

  CreditPackage? _selectedPackage;
  bool _hasAppliedForReferral = false;
  bool _isLoadingReferralStatus = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _selectedPackage = _packages[0]; // Default to First package
    
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

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_selectedPackage != null) {
      await _finalizeCredits(_selectedPackage!.totalCredits);
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

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  void _startPayment() {
    if (_selectedPackage == null) return;

    final user = _supabaseService.currentUser;
    final userEmail = user?.email ?? '';

    var options = {
      'key': _razorpayKeyId,
      'amount': _selectedPackage!.price * 100, // Amount in paise
      'currency': 'INR',
      'name': 'Incoin Pro',
      'description': 'Purchase ${_selectedPackage!.totalCredits} Credits',
      'prefill': {
        'contact': '9999999999',
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      },
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
    };

    try {
      debugPrint('Attempting to open Razorpay Modal...');
      
      if (kIsWeb) {
        // Direct JS call for Web reliability
        RazorpayWeb.openCheckout(
          key: _razorpayKeyId,
          amount: _selectedPackage!.price,
          name: 'Incoin Pro',
          description: '${_selectedPackage!.totalCredits} Credits Package',
          email: _supabaseService.currentUser?.email,
          contact: '9999999999',
          onSuccess: (paymentId) {
            _finalizeCredits(_selectedPackage!.totalCredits);
          },
          onFailure: (code, description) {
            debugPrint('Razorpay Web Failure: $code - $description');
          },
          onDismiss: () {
            debugPrint('Razorpay Web Dismissed');
          },
        );
      } else {
        _razorpay.open(options);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Payment Portal...'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
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
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.blue.withOpacity(0.1) 
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (!isSelected)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                              color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.monetization_on_rounded,
                              color: isSelected ? Colors.white : Colors.amber,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                padding: const EdgeInsets.all(24.0),
                child: CustomButton(
                  text: 'Pay ₹${_selectedPackage?.price ?? 0}',
                  onPressed: _startPayment,
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
        builder: (context) => _ReferralBottomSheet(onApplied: _checkReferralStatus),
      );
    }
  }
  
  // New widget class for the referral bottom sheet (prevents state issues in dialog)
  
  class _ReferralBottomSheet extends StatefulWidget {
    final VoidCallback? onApplied;
    const _ReferralBottomSheet({Key? key, this.onApplied}) : super(key: key);
  
    @override
    State<_ReferralBottomSheet> createState() => _ReferralBottomSheetState();
  }
  
  class _ReferralBottomSheetState extends State<_ReferralBottomSheet> {
    bool _isUploading = false;
    List<XFile> _selectedImages = [];
  
    Future<void> _pickImages() async {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
  
      if (images.isNotEmpty) {
        if (images.length != 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select exactly TWO screenshots.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImages = images;
        });
      }
    }

    Future<void> _uploadImages() async {
      if (_selectedImages.length != 2) return;

      setState(() {
        _isUploading = true;
      });
  
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        List<String> uploadedUrls = [];
        for (int i = 0; i < _selectedImages.length; i++) {
          final fileName = 'referral_${timestamp}_$i.jpg';
          final bytes = await _selectedImages[i].readAsBytes();
          final url = await SupabaseService().uploadReferralScreenshot(bytes, fileName);
          uploadedUrls.add(url);
        }
        
        await SupabaseService().submitReferralApplication(uploadedUrls);
  
        if (mounted) {
          widget.onApplied?.call();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully! Credits will be added soon.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  
    void _launchUrl() async {
      final uri = Uri.parse('https://newh5.incoinpay.net?inviteCode=0113pw1ssa');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  
    @override
    Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.purple, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Get 50 Free Credits',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep(
                      context,
                      stepNumber: '1',
                      title: 'Register with Referral',
                      description: 'Register using our referral link or enter the invite code "0113pw1ssa" during registration.',
                      child: OutlinedButton.icon(
                        onPressed: _launchUrl,
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Open Registration Link'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Image placeholder for step 1
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/step1.jpg',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey.withOpacity(0.2),
                          alignment: Alignment.center,
                          child: const Text('assets/images/step1.jpg missing'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildStep(
                      context,
                      stepNumber: '2',
                      title: 'Take Two Screenshots',
                      description: 'After registering, take a screenshot of your Profile page and another one of your registration confirmation.',
                    ),
                    const SizedBox(height: 16),
                    // Image placeholder for step 2
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/step2.jpg',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey.withOpacity(0.2),
                          alignment: Alignment.center,
                          child: const Text('assets/images/step2.jpg missing'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildStep(
                      context,
                      stepNumber: '3',
                      title: 'Upload Screenshots',
                      description: 'Pick the TWO screenshots using the "Pick Screenshots" button below, then submit.',
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImages.isNotEmpty) ...[
                      const Text('Selected Previews:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: _selectedImages.map((file) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb 
                                    ? Image.network(file.path, height: 120, fit: BoxFit.cover)
                                    : Image.file(File(file.path), height: 120, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    _buildStep(
                      context,
                      stepNumber: '4',
                      title: 'Wait 24 Hours',
                      description: 'Once verified, the 50 credits will automatically be added to your account within 24 hours.',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedImages.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Screenshots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isUploading ? null : () => setState(() => _selectedImages = []),
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _uploadImages,
                                icon: _isUploading 
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.upload_file, color: Colors.white),
                                label: Text(
                                  _isUploading ? 'Submitting...' : 'Submit',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade500,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  
    Widget _buildStep(BuildContext context, {required String stepNumber, required String title, required String description, Widget? child}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: TextStyle(
                color: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child,
                ]
              ],
            ),
          ),
        ],
      );
    }
  }

class CreditPackage {
  final String id;
  final int baseCredits;
  final int extraCredits;
  final int price;
  final String label;

  CreditPackage({
    required this.id,
    required this.baseCredits,
    required this.extraCredits,
    required this.price,
    required this.label,
  });

  int get totalCredits => baseCredits + extraCredits;
}
