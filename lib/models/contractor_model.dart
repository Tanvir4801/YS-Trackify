import 'package:cloud_firestore/cloud_firestore.dart';

class ContractorSubscription {
  final String plan;
  final bool isPremium;
  final DateTime? trialEndsAt;
  final DateTime? renewalDate;
  final int maxLabours;
  final int maxSites;
  final int maxSupervisors;

  ContractorSubscription({
    this.plan = 'Free',
    this.isPremium = false,
    this.trialEndsAt,
    this.renewalDate,
    this.maxLabours = 50,
    this.maxSites = 3,
    this.maxSupervisors = 2,
  });

  factory ContractorSubscription.fromMap(Map<String, dynamic> map) {
    return ContractorSubscription(
      plan: map['plan'] as String? ?? 'Free',
      isPremium: map['isPremium'] as bool? ?? false,
      trialEndsAt: map['trialEndsAt'] != null ? (map['trialEndsAt'] as Timestamp).toDate() : null,
      renewalDate: map['renewalDate'] != null ? (map['renewalDate'] as Timestamp).toDate() : null,
      maxLabours: map['maxLabours'] as int? ?? 50,
      maxSites: map['maxSites'] as int? ?? 3,
      maxSupervisors: map['maxSupervisors'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan,
      'isPremium': isPremium,
      'trialEndsAt': trialEndsAt != null ? Timestamp.fromDate(trialEndsAt!) : null,
      'renewalDate': renewalDate != null ? Timestamp.fromDate(renewalDate!) : null,
      'maxLabours': maxLabours,
      'maxSites': maxSites,
      'maxSupervisors': maxSupervisors,
    };
  }
}

class ContractorFeatures {
  final bool payroll;
  final bool qrAttendance;
  final bool aiReports;
  final bool siteCost;

  ContractorFeatures({
    this.payroll = true,
    this.qrAttendance = true,
    this.aiReports = false,
    this.siteCost = true,
  });

  factory ContractorFeatures.fromMap(Map<String, dynamic> map) {
    return ContractorFeatures(
      payroll: map['payroll'] as bool? ?? true,
      qrAttendance: map['qrAttendance'] as bool? ?? true,
      aiReports: map['aiReports'] as bool? ?? false,
      siteCost: map['siteCost'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payroll': payroll,
      'qrAttendance': qrAttendance,
      'aiReports': aiReports,
      'siteCost': siteCost,
    };
  }
}

class ContractorModel {
  final String id;
  final String name;
  final bool isSuspended;
  final String? suspensionReason;
  final ContractorSubscription subscription;
  final ContractorFeatures features;

  ContractorModel({
    required this.id,
    required this.name,
    this.isSuspended = false,
    this.suspensionReason,
    ContractorSubscription? subscription,
    ContractorFeatures? features,
  })  : subscription = subscription ?? ContractorSubscription(),
        features = features ?? ContractorFeatures();

  factory ContractorModel.fromMap(String id, Map<String, dynamic> map) {
    return ContractorModel(
      id: id,
      name: map['name'] as String? ?? 'Unknown Company',
      isSuspended: map['isSuspended'] as bool? ?? false,
      suspensionReason: map['suspensionReason'] as String?,
      subscription: ContractorSubscription.fromMap(map['subscription'] as Map<String, dynamic>? ?? {}),
      features: ContractorFeatures.fromMap(map['features'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isSuspended': isSuspended,
      'suspensionReason': suspensionReason,
      'subscription': subscription.toMap(),
      'features': features.toMap(),
    };
  }
}
