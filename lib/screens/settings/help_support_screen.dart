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
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surfaceColor(context),
        foregroundColor: AppColors.textPrimaryColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit a Support Ticket',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimaryColor(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Our support team is here to help. Please select the issue category and describe the problem in detail.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondaryColor(context)),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Issue Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textTertiaryColor(context), letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevatedColor(context),
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryColor(context)),
                    style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16),
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
              Text(
                'Description',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textTertiaryColor(context), letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _issueController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    decoration: InputDecoration(
                      hintText: 'Please provide as much detail as possible...',
                      hintStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
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
                      color: _isLoading ? Colors.grey : AppColors.primaryColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: AppColors.textOnPrimaryColor(context), strokeWidth: 2),
                            )
                          : Text(
                              'Submit Ticket',
                              style: TextStyle(
                                color: AppColors.textOnPrimaryColor(context),
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
