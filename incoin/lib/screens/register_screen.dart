import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedState;
  bool _isLoading = false;
  String? _deviceId;

  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  @override
  void initState() {
    super.initState();
    _getDeviceId();
  }

  Future<void> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // Create a fingerprint from browser info
        _deviceId = '${webInfo.browserName.name}_${webInfo.platform ?? ''}_${webInfo.userAgent ?? ''}';
      } else {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id; // Unique Android device ID
      }
    } catch (e) {
      debugPrint('Error getting device id: $e');
      _deviceId = null;
    }
  }

  void _register() async {
    if (_emailController.text.isEmpty || 
        _nameController.text.isEmpty ||
        _passwordController.text.isEmpty || 
        _selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields including Name and State')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Check if this device already has an account
      if (_deviceId != null) {
        final alreadyRegistered = await SupabaseService().isDeviceRegistered(_deviceId!);
        if (alreadyRegistered) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('An account has already been created on this device. Only one account per device is allowed.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      await SupabaseService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        state: _selectedState!,
      );

      // Register the device after successful signup
      if (_deviceId != null) {
        await SupabaseService().registerDevice(_deviceId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please verify your email to continue.')),
        );
        Navigator.of(context).pushReplacementNamed(
          '/verify_email',
          arguments: _emailController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Create Account',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Get 5 FREE credits on signup!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),

              // Form
              CustomTextField(
                controller: _emailController,
                labelText: 'Gmail / Email *',
                hintText: 'Enter your email address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _nameController,
                labelText: 'Full Name *',
                hintText: 'Enter your full name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password *',
                hintText: 'Create a strong password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password *',
                hintText: 'Retype your password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 20),
              // State Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select State *',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: InputDecoration(
                      hintText: 'Select your state',
                      prefixIcon: Icon(Icons.map_outlined, color: Theme.of(context).primaryColor),
                    ),
                    items: _states.map((state) {
                      return DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedState = value);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              CustomButton(
                text: 'Create Account',
                onPressed: _register,
                isLoading: _isLoading,
                icon: Icons.person_add,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
