import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class ReferralBottomSheet extends StatefulWidget {
  final VoidCallback? onApplied;
  const ReferralBottomSheet({Key? key, this.onApplied}) : super(key: key);

  @override
  State<ReferralBottomSheet> createState() => _ReferralBottomSheetState();
}

class _ReferralBottomSheetState extends State<ReferralBottomSheet> {
  bool _isUploading = false;
  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      List<String> uploadedUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = 'referral_${timestamp}_$i.jpg';
        final bytes = await _selectedImages[i].readAsBytes();
        final url = await SupabaseService()
            .uploadReferralScreenshot(bytes, fileName);
        uploadedUrls.add(url);
      }

      await SupabaseService().submitReferralApplication(uploadedUrls);

      if (mounted) {
        widget.onApplied?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Application submitted successfully! Service credits will be added soon.'),
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
                Expanded(
                  child: Text(
                    '🎁 Earn 50 Service Credits – Reward Program',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
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
                  const SizedBox(height: 8),
                  Text(
                    'Want service credits in Incoin Assistant?\n\nFollow these simple steps:',
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    context,
                    stepNumber: '1',
                    title: 'Copy Telegram Link',
                    description: 'Copy our Telegram channel link: ',
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('https://t.me/incoinpro');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.telegram),
                      label: const Text('Open Telegram Channel'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    context,
                    stepNumber: '2',
                    title: 'Share with Friends',
                    description:
                        'Share it with 20 friends and ask them to join',
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    context,
                    stepNumber: '3',
                    title: 'Take Screenshots',
                    description:
                        'Take screenshots after they join (like these examples):',
                    child: SizedBox(
                      height: 220,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildExampleImage('assets/images/step3_example1.jpg'),
                          const SizedBox(width: 10),
                          _buildExampleImage('assets/images/step3_example2.jpg'),
                          const SizedBox(width: 10),
                          _buildExampleImage('assets/images/step3_example3.jpg'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStep(
                    context,
                    stepNumber: '4',
                    title: 'Upload Screenshots',
                    description: 'Upload the screenshots in the app',
                  ),
                  const SizedBox(height: 24),
                  if (_selectedImages.isNotEmpty) ...[
                    const Text('Selected Previews:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _selectedImages.map((file) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(file.path,
                                      height: 120,
                                      width: 80,
                                      fit: BoxFit.cover)
                                  : Image.file(File(file.path),
                                      height: 120,
                                      width: 80,
                                      fit: BoxFit.cover),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'After verification, you will receive 50 Service Credits within 24 hours',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        label: const Text('Pick Screenshots',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isUploading
                                ? null
                                : () => setState(() => _selectedImages = []),
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
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.upload_file,
                                      color: Colors.white),
                              label: Text(
                                _isUploading ? 'Submitting...' : 'Submit',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
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

  Widget _buildStep(BuildContext context,
      {required String stepNumber,
      required String title,
      required String description,
      Widget? child}) {
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

  Widget _buildExampleImage(String assetPath) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                panEnabled: false,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          assetPath,
          width: 140,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
