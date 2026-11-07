import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HousePlanDrawing {
  final String id;
  final String num;
  final String name;
  final String mainName;
  final String category;
  final String status; // 'completed', 'in_progress', 'pending'
  final String? completedDate;
  final String? notes;
  final String verificationStatus; // 'verified', 'pending_admin_verification'
  final String? modifiedByRole; // 'supervisor', 'contractor', 'admin'
  final String? modifiedByName;
  final String? modifiedByUid;
  final String? modifiedAt;

  const HousePlanDrawing({
    required this.id,
    required this.num,
    required this.name,
    required this.mainName,
    required this.category,
    this.status = 'in_progress',
    this.completedDate,
    this.notes,
    this.verificationStatus = 'verified',
    this.modifiedByRole,
    this.modifiedByName,
    this.modifiedByUid,
    this.modifiedAt,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPendingAdminVerification => verificationStatus == 'pending_admin_verification';

  /// Clean display name without leading "01-" or "22-" prefix duplication
  String get displayName {
    if (mainName.isNotEmpty && mainName != name) return mainName;
    final clean = name.replaceFirst(RegExp(r'^\d+[\s\-_.:]*'), '').trim();
    return clean.isNotEmpty ? clean : name;
  }

  factory HousePlanDrawing.fromMap(
    Map<String, dynamic> map, {
    String? fallbackId,
    int? fallbackIndex,
    Set<String>? usedNumbers,
  }) {
    final rawName = (map['name'] as String?) ?? '';
    
    // Robust number extraction: handles string, int, or regex from name
    String numStr = '';
    final rawNum = map['num'];
    if (rawNum != null && rawNum.toString().trim().isNotEmpty) {
      numStr = rawNum.toString().trim();
    }
    
    if (numStr.isEmpty) {
      final match = RegExp(r'^(\d+)').firstMatch(rawName.trim());
      if (match != null) {
        numStr = match.group(1)!;
      } else {
        final splitPart = rawName.split('-').firstOrNull?.trim() ?? '';
        final splitMatch = RegExp(r'^\d+').firstMatch(splitPart);
        if (splitMatch != null) {
          numStr = splitMatch.group(0)!;
        }
      }
    }

    if (numStr.isNotEmpty && numStr.length == 1) {
      numStr = '0$numStr';
    }

    // Auto-repair duplicate "01" badges and assign true sequential numbers:
    // If numStr is empty, OR if numStr is a duplicate (already used by another drawing in this project),
    // assign the sequential 1-based index (e.g. 17, 18, 19, 20...).
    if (numStr.isEmpty || (usedNumbers != null && usedNumbers.contains(numStr))) {
      if (fallbackIndex != null && fallbackIndex > 0) {
        numStr = fallbackIndex.toString().padLeft(2, '0');
      } else if (numStr.isEmpty) {
        numStr = '01';
      }
    }

    if (usedNumbers != null && numStr.isNotEmpty) {
      usedNumbers.add(numStr);
    }

    return HousePlanDrawing(
      id: (map['id'] as String?) ?? fallbackId ?? 'plan_${DateTime.now().microsecondsSinceEpoch}',
      num: numStr,
      name: rawName,
      mainName: (map['mainName'] as String?) ?? rawName,
      category: (map['category'] as String?) ?? 'Architectural',
      status: (map['status'] as String?) ?? 'in_progress',
      completedDate: map['completedDate'] as String?,
      notes: map['notes'] as String?,
      verificationStatus: (map['verificationStatus'] as String?) ?? 'verified',
      modifiedByRole: map['modifiedByRole'] as String?,
      modifiedByName: map['modifiedByName'] as String?,
      modifiedByUid: map['modifiedByUid'] as String?,
      modifiedAt: map['modifiedAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'num': num,
      'name': name,
      'mainName': mainName,
      'category': category,
      'status': status,
      if (completedDate != null) 'completedDate': completedDate,
      if (notes != null) 'notes': notes,
      'verificationStatus': verificationStatus,
      if (modifiedByRole != null) 'modifiedByRole': modifiedByRole,
      if (modifiedByName != null) 'modifiedByName': modifiedByName,
      if (modifiedByUid != null) 'modifiedByUid': modifiedByUid,
      if (modifiedAt != null) 'modifiedAt': modifiedAt,
    };
  }

  HousePlanDrawing copyWith({
    String? status,
    String? completedDate,
    String? notes,
    String? verificationStatus,
    String? modifiedByRole,
    String? modifiedByName,
    String? modifiedByUid,
    String? modifiedAt,
  }) {
    return HousePlanDrawing(
      id: id,
      num: num,
      name: name,
      mainName: mainName,
      category: category,
      status: status ?? this.status,
      completedDate: completedDate ?? this.completedDate,
      notes: notes ?? this.notes,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      modifiedByRole: modifiedByRole ?? this.modifiedByRole,
      modifiedByName: modifiedByName ?? this.modifiedByName,
      modifiedByUid: modifiedByUid ?? this.modifiedByUid,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }
}

class HouseSiteVisit {
  final String id;
  final String date;
  final double amount;
  final String purpose;
  final String notes;
  final String recordedAt;
  final String verificationStatus; // 'verified', 'pending_admin_verification'
  final String? recordedByRole;
  final String? recordedByName;
  final String? recordedByUid;

  const HouseSiteVisit({
    required this.id,
    required this.date,
    required this.amount,
    this.purpose = 'Site Consultation',
    this.notes = '',
    required this.recordedAt,
    this.verificationStatus = 'verified',
    this.recordedByRole,
    this.recordedByName,
    this.recordedByUid,
  });

  bool get isPendingAdminVerification => verificationStatus == 'pending_admin_verification';

  factory HouseSiteVisit.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    final rawAmt = map['amount'];
    final parsedAmt = rawAmt is num ? rawAmt.toDouble() : double.tryParse(rawAmt?.toString() ?? '0') ?? 0.0;
    return HouseSiteVisit(
      id: (map['id'] as String?) ?? fallbackId ?? 'visit_${DateTime.now().microsecondsSinceEpoch}',
      date: (map['date'] as String?) ?? DateTime.now().toIso8601String().split('T')[0],
      amount: parsedAmt,
      purpose: (map['purpose'] as String?) ?? 'Site Consultation',
      notes: (map['notes'] as String?) ?? '',
      recordedAt: (map['recordedAt'] as String?) ?? DateTime.now().toIso8601String(),
      verificationStatus: (map['verificationStatus'] as String?) ?? 'verified',
      recordedByRole: map['recordedByRole'] as String?,
      recordedByName: map['recordedByName'] as String?,
      recordedByUid: map['recordedByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'purpose': purpose,
      'notes': notes,
      'recordedAt': recordedAt,
      'verificationStatus': verificationStatus,
      if (recordedByRole != null) 'recordedByRole': recordedByRole,
      if (recordedByName != null) 'recordedByName': recordedByName,
      if (recordedByUid != null) 'recordedByUid': recordedByUid,
    };
  }
}

class HousePlanPayment {
  final String id;
  final String installmentName;
  final String type;
  final double amount;
  final String date;
  final String mode;
  final String notes;
  final String recordedAt;

  const HousePlanPayment({
    required this.id,
    required this.installmentName,
    this.type = 'advance',
    required this.amount,
    required this.date,
    this.mode = 'UPI',
    this.notes = '',
    required this.recordedAt,
  });

  factory HousePlanPayment.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    final rawAmt = map['amount'];
    final parsedAmt = rawAmt is num ? rawAmt.toDouble() : double.tryParse(rawAmt?.toString() ?? '0') ?? 0.0;
    return HousePlanPayment(
      id: (map['id'] as String?) ?? fallbackId ?? 'pay_${DateTime.now().microsecondsSinceEpoch}',
      installmentName: (map['installmentName'] as String?) ?? 'Payment',
      type: (map['type'] as String?) ?? 'advance',
      amount: parsedAmt,
      date: (map['date'] as String?) ?? DateTime.now().toIso8601String().split('T')[0],
      mode: (map['mode'] as String?) ?? 'UPI',
      notes: (map['notes'] as String?) ?? '',
      recordedAt: (map['recordedAt'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'installmentName': installmentName,
      'type': type,
      'amount': amount,
      'date': date,
      'mode': mode,
      'notes': notes,
      'recordedAt': recordedAt,
    };
  }
}

class HousePlanOwner {
  final String id;
  final String contractorId;
  final String ownerName;
  final String ownerPhone;
  final String villageCity;
  final String plotArea;
  final double totalSqFt;
  final double plotAreaSqFt;
  final String planNo;
  final String serial3D;
  final String supervisingEngineer;
  final double houseAmount;
  final double directTotalPaid;
  final String specsNotes;
  final String status;
  final List<HousePlanDrawing> plansList;
  final List<HouseSiteVisit> siteVisits;
  final List<HousePlanPayment> payments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HousePlanOwner({
    required this.id,
    required this.contractorId,
    required this.ownerName,
    required this.ownerPhone,
    this.villageCity = '',
    this.plotArea = '',
    this.totalSqFt = 0.0,
    this.plotAreaSqFt = 0.0,
    this.planNo = '',
    this.serial3D = '',
    this.supervisingEngineer = '',
    this.houseAmount = 0.0,
    this.directTotalPaid = 0.0,
    this.specsNotes = '',
    this.status = 'active',
    this.plansList = const [],
    this.siteVisits = const [],
    this.payments = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Formatted square footage string (e.g. "2,000 sq.ft") or empty string if zero/missing.
  String get displaySqFt {
    final effectiveSqFt = totalSqFt > 0 ? totalSqFt : plotAreaSqFt;
    if (effectiveSqFt > 0) {
      if (effectiveSqFt == effectiveSqFt.roundToDouble()) {
        final int val = effectiveSqFt.toInt();
        return '${NumberFormat('#,##0', 'en_IN').format(val)} sq.ft';
      } else {
        return '${NumberFormat('#,##0.##', 'en_IN').format(effectiveSqFt)} sq.ft';
      }
    }
    if (plotArea.isNotEmpty) {
      final clean = plotArea.replaceAll(RegExp(r'[^0-9.]'), '').trim();
      final numVal = double.tryParse(clean) ?? 0.0;
      if (numVal > 0) {
        return plotArea.endsWith('sq.ft') ? plotArea : '$plotArea sq.ft';
      }
    }
    return '';
  }

  // ── FINANCIAL & CALCULATION LOGIC (IDENTICAL TO ADMIN WEB) ──

  double get totalVisitsAmount => siteVisits.fold(0.0, (acc, v) => acc + v.amount);

  double get totalBillableAmount => houseAmount + totalVisitsAmount;

  double get calculatedTotalPaid {
    if (payments.isNotEmpty) {
      return payments.fold(0.0, (acc, p) => acc + p.amount);
    }
    return directTotalPaid;
  }

  double get planFeePaid => (calculatedTotalPaid > houseAmount ? houseAmount : calculatedTotalPaid);

  double get planFeePending => (houseAmount - planFeePaid).clamp(0.0, double.infinity);

  bool get isPlanFeeCleared => houseAmount > 0 && planFeePending <= 0;

  double get visitsPaid => (calculatedTotalPaid - houseAmount).clamp(0.0, double.infinity);

  double get visitsPending => (totalVisitsAmount - visitsPaid).clamp(0.0, double.infinity);

  bool get isVisitsCleared => siteVisits.isNotEmpty ? visitsPending <= 0 : true;

  double get netPending => (totalBillableAmount - calculatedTotalPaid).clamp(0.0, double.infinity);

  bool get isFullyCleared => totalBillableAmount > 0 && netPending <= 0;

  int get completedPlansCount => plansList.where((p) => p.isCompleted).length;

  int get totalPlansCount => plansList.length;

  double get progressPercent => totalPlansCount > 0 ? (completedPlansCount / totalPlansCount) : 0.0;

  List<HousePlanDrawing> get completedDrawings =>
      plansList.where((p) => p.isCompleted).toList();

  List<HousePlanDrawing> get inProgressDrawings =>
      plansList.where((p) => !p.isCompleted).toList();

  // ── SUPERVISOR TWO-FACTOR VERIFICATION WORKFLOW ──

  int get pendingVerificationCount =>
      plansList.where((p) => p.isPendingAdminVerification).length +
      siteVisits.where((v) => v.isPendingAdminVerification).length;

  bool get hasPendingSupervisorChanges => pendingVerificationCount > 0;

  List<HousePlanDrawing> get pendingVerificationDrawings =>
      plansList.where((p) => p.isPendingAdminVerification).toList();

  List<HouseSiteVisit> get pendingVerificationVisits =>
      siteVisits.where((v) => v.isPendingAdminVerification).toList();

  factory HousePlanOwner.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Parse drawings (safely handling both Map<String, dynamic> and Map<dynamic, dynamic>)
    final rawPlans = data['plansList'];
    final List<HousePlanDrawing> parsedPlans = [];
    if (rawPlans is List) {
      final Set<String> usedNumbers = {};
      for (int i = 0; i < rawPlans.length; i++) {
        final p = rawPlans[i];
        if (p is Map) {
          try {
            parsedPlans.add(HousePlanDrawing.fromMap(
              Map<String, dynamic>.from(p),
              fallbackId: null,
              fallbackIndex: i + 1,
              usedNumbers: usedNumbers,
            ));
          } catch (_) {}
        }
      }
    }

    // Parse site visits
    final rawVisits = data['siteVisits'];
    final List<HouseSiteVisit> parsedVisits = [];
    if (rawVisits is List) {
      for (final v in rawVisits) {
        if (v is Map) {
          try {
            parsedVisits.add(HouseSiteVisit.fromMap(Map<String, dynamic>.from(v)));
          } catch (_) {}
        }
      }
    }

    // Parse payments
    final rawPayments = data['payments'];
    final List<HousePlanPayment> parsedPayments = [];
    if (rawPayments is List) {
      for (final pay in rawPayments) {
        if (pay is Map) {
          try {
            parsedPayments.add(HousePlanPayment.fromMap(Map<String, dynamic>.from(pay)));
          } catch (_) {}
        }
      }
    }

    final rawHouseAmt = data['houseAmount'];
    final double parsedHouseAmount = rawHouseAmt is num
        ? rawHouseAmt.toDouble()
        : double.tryParse(rawHouseAmt?.toString() ?? '0') ?? 0.0;

    final rawPaid = data['totalPaid'];
    final double parsedTotalPaid = rawPaid is num
        ? rawPaid.toDouble()
        : double.tryParse(rawPaid?.toString() ?? '0') ?? 0.0;

    DateTime? parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    final villageCity = (data['villageCity'] as String?) ??
        (data['city'] as String?) ??
        (data['town'] as String?) ??
        '';

    double parseSqFt(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(RegExp(r'[^0-9.]'), '').trim();
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    final double parsedTotalSqFt = parseSqFt(
      data['totalSqFt'] ?? data['houseSqFt'] ?? data['builtUpArea'] ?? data['totalArea'],
    );
    final double parsedPlotAreaSqFt = parseSqFt(
      data['plotAreaSqFt'] ?? data['plotSqFt'],
    );

    String rawPlotArea = (data['plotArea'] as String?)?.trim() ?? '';
    if (rawPlotArea == '0' || rawPlotArea == '0 sq.ft' || rawPlotArea == '0.0 sq.ft' || rawPlotArea == '0.0') {
      rawPlotArea = '';
    }

    String finalPlotArea = rawPlotArea;
    if (finalPlotArea.isEmpty) {
      final effective = parsedTotalSqFt > 0 ? parsedTotalSqFt : parsedPlotAreaSqFt;
      if (effective > 0) {
        if (effective == effective.roundToDouble()) {
          finalPlotArea = '${NumberFormat('#,##0', 'en_IN').format(effective.toInt())} sq.ft';
        } else {
          finalPlotArea = '${NumberFormat('#,##0.##', 'en_IN').format(effective)} sq.ft';
        }
      }
    }

    final planNo = (data['planNo'] as String?) ??
        (data['planNumber'] as String?) ??
        '';

    final serial3D = (data['serial3D'] as String?) ??
        (data['serialNumber3D'] as String?) ??
        '';

    return HousePlanOwner(
      id: doc.id,
      contractorId: (data['contractorId'] as String?) ?? '',
      ownerName: (data['ownerName'] as String?) ?? 'Unknown Client',
      ownerPhone: (data['ownerPhone'] as String?) ?? '',
      villageCity: villageCity,
      plotArea: finalPlotArea,
      totalSqFt: parsedTotalSqFt,
      plotAreaSqFt: parsedPlotAreaSqFt,
      planNo: planNo,
      serial3D: serial3D,
      supervisingEngineer: (data['supervisingEngineer'] as String?) ?? (data['engineerName'] as String?) ?? '',
      houseAmount: parsedHouseAmount,
      directTotalPaid: parsedTotalPaid,
      specsNotes: (data['specsNotes'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'active',
      plansList: parsedPlans,
      siteVisits: parsedVisits,
      payments: parsedPayments,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}
