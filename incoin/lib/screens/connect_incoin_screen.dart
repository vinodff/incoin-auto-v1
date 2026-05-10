import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/incoin_api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class ConnectIncoinScreen extends StatefulWidget {
  const ConnectIncoinScreen({Key? key}) : super(key: key);

  @override
  State<ConnectIncoinScreen> createState() => _ConnectIncoinScreenState();
}

class _ConnectIncoinScreenState extends State<ConnectIncoinScreen> {
  // ── Controllers ────────────────────────────────────────────────
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController  = TextEditingController();
  final _storage            = const FlutterSecureStorage();

  // ── Captcha state ───────────────────────────────────────────────
  Uint8List? _captchaImageBytes;
  String     _captchaToken    = '';
  bool       _captchaLoading  = false;
  String?    _captchaError;

  // ── App keys (needed for signed login) ─────────────────────────
  String? _appKey;
  String? _appSecret;

  // ── Login state ─────────────────────────────────────────────────
  bool    _isLoading = false;
  String? _loginError;

  // ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _initKeys();
  }

  Future<void> _loadSavedCredentials() async {
    final username = await _storage.read(key: 'incoin_username');
    final password = await _storage.read(key: 'incoin_password');

    if (mounted && (username != null || password != null)) {
      setState(() {
        _usernameController.text = username ?? '';
        _passwordController.text = password ?? '';
      });
    }
  }

  Future<void> _initKeys() async {
    // Fetch app keys silently in the background while the screen loads.
    final keys = await IncoinApiService.fetchAppKeys();
    if (mounted && keys != null) {
      setState(() {
        _appKey    = keys.key;
        _appSecret = keys.secret;
      });
    }
    // After keys are ready, fetch the captcha.
    _fetchCaptcha();
  }

  Future<void> _fetchCaptcha() async {
    if (!mounted) return;
    setState(() {
      _captchaLoading = true;
      _captchaError   = null;
      _captchaImageBytes = null;
      _captchaController.clear();
    });

    final result = await IncoinApiService.fetchCaptcha();

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _captchaLoading = false;
        _captchaError   = 'Could not load captcha. Check your connection.';
      });
      return;
    }
    setState(() {
      _captchaLoading    = false;
      _captchaImageBytes = result.imageBytes;
      _captchaToken      = result.token;
    });
  }

  // ── Save & verify credentials ──────────────────────────────────

  Future<void> _saveAndConnect() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final captcha  = _captchaController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password.')),
      );
      return;
    }

    if (captcha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the captcha code.')),
      );
      return;
    }

    if (_appKey == null || _appSecret == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not reach backend servers. Check your internet.')),
      );
      return;
    }

    setState(() {
      _isLoading  = true;
      _loginError = null;
    });

    // Attempt login to verify credentials are correct before saving.
    final loginResult = await IncoinApiService.login(
      appKey:       _appKey!,
      appSecret:    _appSecret!,
      username:     username,
      password:     password,
      captchaCode:  captcha,
      captchaToken: _captchaToken,
    );

    if (!mounted) return;

    if (!loginResult.success) {
      setState(() {
        _isLoading  = false;
        _loginError = loginResult.errorMessage ?? 'Login failed.';
      });
      // Refresh captcha for retry.
      _fetchCaptcha();
      return;
    }

    // Login succeeded — save credentials securely.
    await _storage.write(key: 'incoin_username', value: username);
    await _storage.write(key: 'incoin_password', value: password);
    await _storage.write(key: 'incoin_token', value: loginResult.authToken);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Service account integrated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Integration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info banner ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your credentials are stored securely on-device using encryption. They are never sent to any third-party server.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.amber[800],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Fields ───────────────────────────────────────────
              CustomTextField(
                controller: _usernameController,
                labelText: 'Account Username / ID',
                hintText: 'Enter your service username',
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Account Password',
                hintText: 'Enter your service password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 28),

              // ── Captcha section ──────────────────────────────────
              Text(
                'Captcha Verification',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              _buildCaptchaBox(context),
              const SizedBox(height: 14),

              // Captcha text input
              CustomTextField(
                controller: _captchaController,
                labelText: 'Enter Captcha',
                hintText: 'Type the code shown above',
                prefixIcon: Icons.security,
                keyboardType: TextInputType.visiblePassword,
              ),

              // Login error message
              if (_loginError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loginError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 36),

              // ── Submit button ────────────────────────────────────
              CustomButton(
                text: 'Verify & Integrate',
                onPressed: _isLoading ? () {} : _saveAndConnect,
                isLoading: _isLoading,
                icon: Icons.link,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Captcha image widget ───────────────────────────────────────

  Widget _buildCaptchaBox(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // ── Image area ─────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: _buildCaptchaImage(),
            ),
          ),

          // ── Refresh button ─────────────────────────────────────
          Container(
            width: 56,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
              ),
            ),
            child: IconButton(
              icon: _captchaLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh captcha',
              onPressed: _captchaLoading ? null : _fetchCaptcha,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptchaImage() {
    if (_captchaLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_captchaError != null) {
      return Center(
        child: Text(
          _captchaError!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_captchaImageBytes != null) {
      return Image.memory(
        _captchaImageBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return const Center(
      child: Text(
        'Loading captcha…',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }
}
