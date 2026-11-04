import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';
import '../utils/calc_constants.dart';

class CalcGuideCard extends StatelessWidget {
  final String title;
  final List<String> steps;
  final String formula;

  const CalcGuideCard({
    super.key,
    this.title = 'HOW IT WORKS',
    required this.steps,
    required this.formula,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CalcColors.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalcColors.border(context), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: CalcColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: CalcColors.amber(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        color: CalcColors.amber(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: CalcColors.textPrimary(context),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Formula',
            style: TextStyle(
              color: CalcColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formula,
            style: TextStyle(
              color: CalcColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class CalcResultHeader extends StatelessWidget {
  final String title;
  final String value;
  final String? formula;
  final bool isWarning;
  final String? warningText;

  const CalcResultHeader({
    super.key,
    required this.title,
    required this.value,
    this.formula,
    this.isWarning = false,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalcColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalcColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: CalcColors.amber(context).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: CalcColors.textSecondary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: CalcColors.amber(context),
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (formula != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CalcColors.surface(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formula!,
                style: TextStyle(
                  color: CalcColors.textMuted(context),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (isWarning && warningText != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: CalcColors.red(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CalcColors.red(context).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: CalcColors.red(context), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText!,
                      style: TextStyle(
                        color: CalcColors.red(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CalcMaterialRow {
  final String label;
  final String value;
  CalcMaterialRow(this.label, this.value);
}

class CalcMaterialTable extends StatelessWidget {
  final String title;
  final List<CalcMaterialRow> rows;

  const CalcMaterialTable({
    super.key,
    this.title = 'MATERIALS REQUIRED',
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: CalcColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CalcColors.border(context)),
          ),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(
                    bottom: BorderSide(color: CalcColors.border(context), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.value.label,
                      style: TextStyle(
                        color: CalcColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      e.value.value,
                      style: TextStyle(
                        color: CalcColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class CalcDetailSection extends StatelessWidget {
  final String title;
  final Map<String, String> details;

  const CalcDetailSection({
    super.key,
    this.title = 'CALCULATION DETAILS',
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CalcColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CalcColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          color: CalcColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: CalcColors.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class CalcActionRow extends StatelessWidget {
  final VoidCallback onRecalculate;
  final VoidCallback onReset;

  const CalcActionRow({
    super.key,
    required this.onRecalculate,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: CalcColors.border(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: CalcColors.textPrimary(context),
            ),
            child: Text('Reset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onRecalculate,
            style: FilledButton.styleFrom(
              backgroundColor: CalcColors.amber(context),
              foregroundColor: CalcColors.amberText(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Recalculate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

Widget _buildSectionHeader(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: CalcColors.textSecondary(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}
