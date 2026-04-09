import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../main.dart';
import '../services/auth/supervisor_auth_service.dart';

class SupervisorPinScreen extends StatefulWidget {
  const SupervisorPinScreen({super.key});

  @override
  State<SupervisorPinScreen> createState() => _SupervisorPinScreenState();
}

class _SupervisorPinScreenState extends State<SupervisorPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final SupervisorAuthService _authService = SupervisorAuthService();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      setState(() {
        _errorText = 'Enter a valid 4-digit PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final isValid = await _authService.validatePin(pin);

    if (!mounted) {
      return;
    }

    if (!isValid) {
      setState(() {
        _isLoading = false;
        _errorText = 'Incorrect PIN. Please try again.';
      });
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.supervisorShell);
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Supervisor PIN')),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF2F8FC),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
         

           Positioned(
            top:250,
            left: 90,
            child: Icon(
              Icons.home_work_outlined,
              size: 100,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
        

  Positioned(
            right: -20,
            
            bottom: -50,
            child: Transform.rotate(
              angle: -0.14,
              child: Icon(
                Icons.roofing_outlined,
                size: 190,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        kToolbarHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Enter 4-digit PIN',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: _errorText,
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _submitPin(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _isLoading ? null : _submitPin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Login'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Secure access for supervisors',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color.fromARGB(255, 21, 39, 54).withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      
    );
  }
}
