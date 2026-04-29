import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';

enum _LoginMode { supervisor, labour }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  // Supervisor form
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _supervisorFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // Labour form
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _labourFormKey = GlobalKey<FormState>();

  _LoginMode _mode = _LoginMode.supervisor;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _switchMode(_LoginMode mode) {
    if (_mode == mode || _isLoading) return;
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final isSupervisor = _mode == _LoginMode.supervisor;
    final formKey = isSupervisor ? _supervisorFormKey : _labourFormKey;
    if (!formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final AuthResult result = isSupervisor
        ? await _authService.loginWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await _authService.labourLoginByPhone(_phoneController.text);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
      return;
    }

    if (isSupervisor) {
      if (result.role == 'supervisor' || result.role == 'admin') {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/supervisor-home', (route) => false);
        return;
      }
      // Supervisor tab signed in, but role isn't supervisor/admin — block.
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/unauthorized', (route) => false);
      return;
    }

    // Labour tab — only labour role is valid here.
    if (result.role == 'labour') {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/labour-home', (route) => false);
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/unauthorized', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.construction,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TRACKIFY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Labour Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == _LoginMode.supervisor
                      ? 'Sign in as supervisor'
                      : 'Sign in as labour',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                _ModeSwitcher(
                  mode: _mode,
                  onChanged: _switchMode,
                ),
                const SizedBox(height: 24),
                if (_mode == _LoginMode.supervisor)
                  _buildSupervisorForm()
                else
                  _buildLabourForm(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor:
                          const Color(0xFF1E40AF).withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _mode == _LoginMode.supervisor
                                ? 'Sign In'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'This app is for:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoleTag(
                            icon: Icons.supervisor_account,
                            label: 'Supervisors',
                            color: Colors.blue,
                          ),
                          _RoleTag(
                            icon: Icons.person,
                            label: 'Labours',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupervisorForm() {
    return Form(
      key: _supervisorFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (val) {
              final v = (val ?? '').trim();
              if (v.isEmpty) return 'Please enter your email';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Password',
              icon: Icons.lock_outlined,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabourForm() {
    return Form(
      key: _labourFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
            decoration: _inputDecoration(
              label: 'Mobile Number',
              icon: Icons.phone_android,
              hint: '10-digit number',
            ),
            validator: (val) {
              final v = (val ?? '').trim();
              if (v.isEmpty) return 'Please enter your mobile number';
              if (v.length != 10) return 'Enter a valid 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'No password needed. Login with your registered mobile number.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});

  final _LoginMode mode;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab(
            label: 'Supervisor',
            icon: Icons.supervisor_account,
            selected: mode == _LoginMode.supervisor,
            onTap: () => onChanged(_LoginMode.supervisor),
          ),
          _buildTab(
            label: 'Labour',
            icon: Icons.person,
            selected: mode == _LoginMode.labour,
            onTap: () => onChanged(_LoginMode.labour),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E40AF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
