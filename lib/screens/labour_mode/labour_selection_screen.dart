import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_text.dart';
import '../../models/labour.dart';
import '../../providers/language_provider.dart';
import '../../providers/site_data_provider.dart';
import '../../services/auth/labour_auth_service.dart';
import 'labour_mode_shell.dart';

class LabourSelectionScreen extends StatefulWidget {
  const LabourSelectionScreen({super.key});

  @override
  State<LabourSelectionScreen> createState() => _LabourSelectionScreenState();
}

class _LabourSelectionScreenState extends State<LabourSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isSubmitting = false;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreSession();
    });
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _tryRestoreSession() async {
    final hiveService = context.read<SiteDataProvider>().hiveService;
    final authService = LabourAuthService(hiveService: hiveService);
    final sessionLabour = await authService.getSessionLabour();

    if (!mounted) {
      return;
    }

    if (sessionLabour == null) {
      setState(() {
        _restoringSession = false;
      });
      return;
    }

    _goToLabourDashboard(sessionLabour);
  }

  Future<void> _login() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    final hiveService = context.read<SiteDataProvider>().hiveService;
    final authService = LabourAuthService(hiveService: hiveService);
    final labour = await authService.loginWithMobile(_mobileController.text.trim());

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (labour == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.tr('mobileNotFound')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      return;
    }

    _goToLabourDashboard(labour);
  }

  String? _mobileValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return context.tr('mobileRequired');
    }

    final hiveService = context.read<SiteDataProvider>().hiveService;
    final authService = LabourAuthService(hiveService: hiveService);
    if (!authService.isValidMobile(text)) {
      return context.tr('mobileInvalid');
    }
    return null;
  }

  void _goToLabourDashboard(Labour labour) {
    final hiveService = context.read<SiteDataProvider>().hiveService;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LabourModeShell(
          labour: labour,
          hiveService: hiveService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;

    if (_restoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('labourMode')),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<AppLanguage>(
              value: language,
              borderRadius: BorderRadius.circular(12),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                context.read<LanguageProvider>().setLanguage(value);
              },
              items: [
                DropdownMenuItem(
                  value: AppLanguage.english,
                  child: Text(context.tr('english')),
                ),
                DropdownMenuItem(
                  value: AppLanguage.hindi,
                  child: Text(context.tr('hindi')),
                ),
                DropdownMenuItem(
                  value: AppLanguage.gujarati,
                  child: Text(context.tr('gujarati')),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('labourLoginTitle'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('labourLoginSubtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  maxLength: 13,
                  decoration: InputDecoration(
                    labelText: context.tr('mobileNumber'),
                    hintText: context.tr('mobileNumberHint'),
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: _mobileValidator,
                  onFieldSubmitted: (_) => _isSubmitting ? null : _login(),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _login,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.login),
                  label: Text(context.tr('login')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
