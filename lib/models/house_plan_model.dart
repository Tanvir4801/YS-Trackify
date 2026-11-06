import 'package:cloud_firestore/cloud_firestore.dart';

class HousePlanDrawing {
  final String id;
  final String num;
  final String name;
  final String mainName;
  final String category;
  final String status; // 'completed', 'in_progress', 'pending'
  final String? completedDate;
  final String? notes;

  const HousePlanDrawing({
    required this.id,
    required this.num,
    required this.name,
    required this.mainName,
    required this.category,
    this.status = 'in_progress',
    this.completedDate,
    this.notes,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';

  factory HousePlanDrawing.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    final rawName = (map['name'] as String?) ?? '';
    final numStr = (map['num'] as String?) ?? (rawName.split('-').firstOrNull?.trim() ?? '01');
    return HousePlanDrawing(
      id: (map['id'] as String?) ?? fallbackId ?? 'plan_${DateTime.now().microsecondsSinceEpoch}',
      num: numStr,
      name: rawName,
      mainName: (map['mainName'] as String?) ?? rawName,
      category: (map['category'] as String?) ?? 'Architectural',
      status: (map['status'] as String?) ?? 'in_progress',
      completedDate: map['completedDate'] as String?,
      notes: map['notes'] as String?,
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
    };
  }

  HousePlanDrawing copyWith({
    String? status,
    String? completedDate,
    String? notes,
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

  const HouseSiteVisit({
    required this.id,
    required this.date,
    required this.amount,
    this.purpose = 'Site Consultation',
    this.notes = '',
    required this.recordedAt,
  });

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

  factory HousePlanOwner.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Parse drawings
    final rawPlans = data['plansList'];
    final List<HousePlanDrawing> parsedPlans = [];
    if (rawPlans is List) {
      for (final p in rawPlans) {
        if (p is Map<String, dynamic>) {
          parsedPlans.add(HousePlanDrawing.fromMap(p));
        }
      }
    }

    // Parse site visits
    final rawVisits = data['siteVisits'];
    final List<HouseSiteVisit> parsedVisits = [];
    if (rawVisits is List) {
      for (final v in rawVisits) {
        if (v is Map<String, dynamic>) {
          parsedVisits.add(HouseSiteVisit.fromMap(v));
        }
      }
    }

    // Parse payments
    final rawPayments = data['payments'];
    final List<HousePlanPayment> parsedPayments = [];
    if (rawPayments is List) {
      for (final pay in rawPayments) {
        if (pay is Map<String, dynamic>) {
          parsedPayments.add(HousePlanPayment.fromMap(pay));
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

    return HousePlanOwner(
      id: doc.id,
      contractorId: (data['contractorId'] as String?) ?? '',
      ownerName: (data['ownerName'] as String?) ?? 'Unknown Client',
      ownerPhone: (data['ownerPhone'] as String?) ?? '',
      villageCity: (data['villageCity'] as String?) ?? '',
      plotArea: (data['plotArea'] as String?) ?? '',
      planNo: (data['planNo'] as String?) ?? '',
      serial3D: (data['serial3D'] as String?) ?? '',
      supervisingEngineer: (data['supervisingEngineer'] as String?) ?? '',
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
