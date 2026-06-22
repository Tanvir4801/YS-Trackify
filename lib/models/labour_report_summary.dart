class LabourReportSummary {
  LabourReportSummary({
    required this.labourName,
    required this.role,
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.totalEarned,
    required this.overtimePay,
    required this.advanceAmount,
    required this.extraHours,
  });

  final String labourName;
  final String role;
  final int presentDays;
  final int halfDays;
  final int absentDays;
  final double totalEarned;
  final double overtimePay;
  final double advanceAmount;
  final double extraHours;

  double get effectiveWorkdays => presentDays + (halfDays * 0.5);
  double get finalPay => totalEarned + overtimePay - advanceAmount;
}
