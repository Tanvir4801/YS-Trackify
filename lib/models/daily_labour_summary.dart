class DailyLabourSummary {
  DailyLabourSummary({
    required this.labourId,
    required this.totalShiftFactor,
    required this.siteVisits,
  });

  final String labourId;
  double totalShiftFactor; // mutable — we add to it
  final List<SiteVisit> siteVisits;

  bool get isFullyCommitted => totalShiftFactor >= 1.0 - 0.001;
  double get remainingFactor => (1.0 - totalShiftFactor).clamp(0.0, 1.0);
  bool get canWorkHalfMore  => remainingFactor >= 0.5 - 0.001;
  bool get canWorkFullMore  => remainingFactor >= 1.0 - 0.001;

  String get statusBadge {
    if (isFullyCommitted)     return 'FULL';
    if (totalShiftFactor > 0) return 'PARTIAL';
    return 'AVAILABLE';
  }

  String get remainingLabel {
    if (isFullyCommitted)       return 'Full day done';
    if (remainingFactor >= 1.0) return 'Full day available';
    if (remainingFactor >= 0.5) return '½ day available';
    return '${(remainingFactor * 100).round()}% available';
  }
}

class SiteVisit {
  const SiteVisit({
    required this.siteId,
    required this.siteName,
    required this.status,
    required this.factor,
    required this.docId,
  });

  final String siteId;
  final String siteName;
  final String status;
  final double factor;
  final String docId;

  String get factorLabel => factor >= 1.0 ? 'Full' : 'Half';
}

class AttendanceException implements Exception {
  const AttendanceException(this.message, {this.code = ''});
  final String message;
  final String code;
  @override String toString() => message;
}
