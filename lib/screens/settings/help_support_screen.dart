import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/support_ticket_service.dart';
import '../../services/telemetry_service.dart';
import '../../widgets/animations/bouncy_tap.dart';
import '../../core/utils/snackbar_utils.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _issueController = TextEditingController();
  
  final List<String> _ticketTypes = [
    'Attendance Issue',
    'Payment Issue',
    'Salary Issue',
    'App Crash',
    'QR Issue',
    'Feature Request',
    'Subscription Issue',
    'Suggestion',
    'Bug Report'
  ];
  
  String _selectedType = 'Attendance Issue';
  bool _isLoading = false;

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    TelemetryService.instance.trackFeatureUsage('Support Ticket Created');
    final issue = _issueController.text.trim();
    if (issue.isEmpty) {
      AppSnackBar.showError(context, 'Please describe your issue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupportTicketService.instance.createTicket(
        type: _selectedType,
        issue: issue,
        currentScreen: 'HelpSupportScreen',
        priority: (_selectedType == 'App Crash' || _selectedType == 'Payment Issue' || _selectedType == 'Subscription Issue') 
            ? 'High' : 'Medium',
      );
      
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'Ticket submitted successfully. Support will contact you soon.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Failed to submit ticket. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submit a Support Ticket',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our support team is here to help. Please select the issue category and describe the problem in detail.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Issue Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: AppColors.navyLight,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedType = newValue);
                      }
                    },
                    items: _ticketTypes.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Description',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.navyLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _issueController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Please provide as much detail as possible...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: BouncyTap(
                  onTap: _isLoading ? () {} : () { _submitTicket(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2),
                            )
                          : const Text(
                              'Submit Ticket',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
