import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String? _errorMessage;
  String _enteredPhone = '';

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length != 10) {
      setState(() => _errorMessage = 'Enter valid 10 digit number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.sendOTP(
      phone: phone,
      onCodeSent: (verificationId) {
        if (!mounted) {
          return;
        }
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _enteredPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      },
      onAutoVerify: (credential) async {
        if (!mounted) {
          return;
        }
        setState(() => _isLoading = true);
        final result = await _authService.signInWithCredential(credential);
        _handleAuthResult(result);
      },
    );
  }

  Future<void> _verifyOTP() async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      setState(() {
        _errorMessage = 'OTP session expired. Please resend OTP.';
      });
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Enter 6 digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyOTP(
      verificationId: verificationId,
      otp: otp,
    );
    _handleAuthResult(result);
  }

  void _handleAuthResult(AuthResult result) {
    if (!mounted) {
      return;
    }

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
      return;
    }

    if (result.role == 'supervisor' || result.role == 'admin') {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/supervisor-home',
        (route) => false,
      );
      return;
    }

    if (result.role == 'labour') {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/labour-home',
        (route) => false,
      );
      return;
    }

    setState(() {
      _errorMessage = 'Unknown role. Contact admin.';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otpSent ? 'Enter OTP' : 'Trackify Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_otpSent) ...[
              const Text(
                'Enter mobile number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: 'Phone Number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ] else ...[
              Text(
                'OTP sent to +91 $_enteredPhone',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter OTP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: '6 digit OTP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _otpSent = false;
                          _otpController.clear();
                          _errorMessage = null;
                          _verificationId = null;
                        });
                      },
                child: const Text('Change number'),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1A6B5A),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _otpSent ? 'VERIFY OTP' : 'SEND OTP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
            if (!_otpSent) ...[
              const SizedBox(height: 16),
              const Text(
                'By continuing, you will receive a one-time verification code.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
