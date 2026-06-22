import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

enum ResultType { safe, unsafe, neutral }

class ResultCard extends StatelessWidget {
  final String mainValue;
  final String mainLabel;
  final List<ResultRowData> rows;
  final String? noteText;
  final ResultType type;
  final String? warningText;

  const ResultCard({
    super.key,
    required this.mainValue,
    required this.mainLabel,
    required this.rows,
    this.noteText,
    this.type = ResultType.neutral,
    this.warningText,
  });

  Color get _bg => switch (type) {
    ResultType.safe   => CalcColors.greenLight,
    ResultType.unsafe => CalcColors.redLight,
    ResultType.neutral=> CalcColors.greenLight,
  };
  Color get _border => switch (type) {
    ResultType.safe   => CalcColors.greenBorder,
    ResultType.unsafe => CalcColors.redBorder,
    ResultType.neutral=> CalcColors.greenBorder,
  };
  Color get _mainColor => switch (type) {
    ResultType.safe   => CalcColors.green,
    ResultType.unsafe => CalcColors.red,
    ResultType.neutral=> CalcColors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (ctx, val, child) =>
                  Opacity(opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - val)),
                      child: child)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mainValue,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: _mainColor,
                      )),
                    const SizedBox(height: 2),
                    Text(mainLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: type == ResultType.unsafe
                          ? CalcColors.redMid
                          : CalcColors.greenMid,
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...rows.asMap().entries.map((e) =>
                _ResultRow(
                  data: e.value,
                  isLast: e.key == rows.length - 1,
                  type: type,
                )),
              if (noteText != null) ...[
                const SizedBox(height: 8),
                Text(noteText!,
                  style: CalcTextStyles.resultNote),
              ],
            ],
          ),
        ),
        if (warningText != null)
          _WarningCard(text: warningText!),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final ResultRowData data;
  final bool isLast;
  final ResultType type;

  const _ResultRow({
    required this.data,
    required this.isLast,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: type == ResultType.unsafe
              ? const Color(0xFFFECACA)
              : CalcColors.greenDivider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(data.label,
            style: TextStyle(
              fontSize: 13,
              color: type == ResultType.unsafe
                ? CalcColors.redMid
                : CalcColors.greenMid,
            )),
          Text(data.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: type == ResultType.unsafe
                ? CalcColors.redDark
                : CalcColors.greenDark,
            )),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String text;
  const _WarningCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CalcColors.warnBg,
        border: Border.all(color: CalcColors.warnBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
            size: 16, color: CalcColors.warnIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: const TextStyle(
                fontSize: 12,
                color: CalcColors.warnText,
                height: 1.5,
              )),
          ),
        ],
      ),
    );
  }
}

class ResultRowData {
  final String label;
  final String value;
  const ResultRowData(this.label, this.value);
}
