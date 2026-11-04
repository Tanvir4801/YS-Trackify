import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../models/calc_history_item.dart';
import '../widgets/calc_result_widgets.dart';

class HistoryDetailScreen extends StatelessWidget {
  final CalcHistoryItem item;

  const HistoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        title: Text('${item.category} Details', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: IconThemeData(color: AppColors.textPrimaryColor(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Calculated on ${DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp)}',
                style: TextStyle(color: AppColors.primaryColor(context), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            
            // Reconstruct the result view from item.results if available
            if (item.results != null) ...[
              if (item.results!['mainValue'] != null)
                CalcResultHeader(
                  title: item.results!['mainTitle'] ?? 'Result',
                  value: item.results!['mainValue'],
                  formula: item.results!['formula'],
                ),
              
              if (item.results!['materials'] != null)
                CalcMaterialTable(
                  title: 'MATERIALS REQUIRED',
                  rows: (item.results!['materials'] as List).map((m) {
                    final map = m as Map<String, dynamic>;
                    return CalcMaterialRow(map['label'] ?? '', map['value'] ?? '');
                  }).toList(),
                ),
            ] else ...[
              // Fallback for old history items
              CalcResultHeader(
                title: 'Result',
                value: item.title,
              ),
            ],

            if (item.inputs != null)
              CalcDetailSection(
                title: 'CALCULATION DETAILS',
                details: item.inputs!.map((key, value) => MapEntry(key, value.toString())),
              ),
              
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context, item.inputs); // Return inputs to Use Again
                },
                icon: const Icon(Icons.restore),
                label: const Text('Use Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryColor(context),
                  foregroundColor: AppColors.textOnPrimaryColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
