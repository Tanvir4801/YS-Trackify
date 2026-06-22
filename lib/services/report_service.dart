import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import '../models/payment_model.dart';
import 'firestore_paths.dart';
import 'session_service.dart';

class ReportService {
  ReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Box<Attendance>? attendanceBox,
    Box<Labour>? labourBox,
    Box<Payment>? paymentBox,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _attendanceBox = attendanceBox ?? Hive.box<Attendance>(Attendance.boxName),
        _labourBox = labourBox ?? Hive.box<Labour>(Labour.boxName),
        _paymentBox = paymentBox ?? Hive.box<Payment>(Payment.boxName);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Box<Attendance> _attendanceBox;
  final Box<Labour> _labourBox;
  final Box<Payment> _paymentBox;

  String get supervisorId => _auth.currentUser!.uid;

  String _resolvedContractorId() {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return '';
    for (final labour in _labourBox.values) {
      if (labour.contractorId.isNotEmpty) return labour.contractorId;
    }
    return uid;
  }

  Future<void> fetchMonthData(int month, int year) async {
    final monthStr     = '$year-${month.toString().padLeft(2, '0')}';
    final contractorId = _resolvedContractorId();

    try {
      final ids = <String>{};

      final attSnap = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: supervisorId)
          .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
          .where('date', isLessThanOrEqualTo: '$monthStr-31')
          .get();
      for (final doc in attSnap.docs) {
        final att = Attendance.fromFirestore(doc);
        await _attendanceBox.put(att.id, att);
        ids.add(att.id);
      }

      if (contractorId.isNotEmpty) {
        final contractorSnap = await _db
            .collection('attendance')
            .where('contractorId', isEqualTo: contractorId)
            .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
            .where('date', isLessThanOrEqualTo: '$monthStr-31')
            .get();
        for (final doc in contractorSnap.docs) {
          final att = Attendance.fromFirestore(doc);
          if (ids.add(att.id)) {
            await _attendanceBox.put(att.id, att);
          }
        }
      }

      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        final dateKey =
            '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        try {
          if (contractorId.isEmpty) continue;
          final nestedSnap =
              await FirestorePaths.attendanceRecordsCol(contractorId, dateKey).get();
          for (final doc in nestedSnap.docs) {
            final data    = doc.data();
            final labourId = (data['labourId'] as String?) ?? doc.id;
            final docId   = '${labourId}_$dateKey';
            final att     = Attendance(
              id:           docId,
              labourId:     labourId,
              supervisorId: (data['supervisorId'] as String?) ?? supervisorId,
              contractorId: (data['contractorId'] as String?) ?? contractorId,
              siteId:       (data['siteId'] as String?) ?? (data['supervisorId'] as String?) ?? supervisorId,
              date:         dateKey,
              status:       AttendanceStatusX.fromFirestoreValue(data['status'] as String?),
              overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
              remark:       (data['remark'] as String?) ?? (data['notes'] as String?) ?? '',
              wageAtTime:   (data['wageAtTime'] as num?)?.toDouble() ?? 0,
            )..isSynced = true;
            if (ids.add(att.id)) {
              await _attendanceBox.put(att.id, att);
            }
          }
        } catch (e) {
          debugPrint('Nested month fetch failed for $dateKey: $e');
        }
      }

      final startDate = DateTime(year, month, 1);
      final endDate   = DateTime(year, month + 1, 0, 23, 59, 59);
      final paySnap = await _db
          .collection('payments')
          .where('supervisorId', isEqualTo: supervisorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      for (final doc in paySnap.docs) {
        final pay = Payment.fromFirestore(doc);
        await _paymentBox.put(pay.id, pay);
      }

      debugPrint('Fetched data for $monthStr (attendance=${ids.length})');
    } catch (e) {
      debugPrint('Fetch month data failed: $e');
    }
  }

  // generateSalaryReport uses wageAtTime for historical accuracy
  List<Map<String, dynamic>> generateSalaryReport(int month, int year) {
    final monthStr     = '$year-${month.toString().padLeft(2, '0')}';
    final contractorId = _resolvedContractorId();
    final labours      = _labourBox.values
        .where((l) =>
            l.isActive &&
            !l.isTemporary &&
            (l.supervisorId == supervisorId ||
                (contractorId.isNotEmpty && l.contractorId == contractorId) ||
                l.contractorId == supervisorId))
        .toList();

    return labours.map((labour) {
      final records = _attendanceBox.values
          .where((a) => a.labourId == labour.id && a.date.startsWith(monthStr))
          .toList();

      final daysPresent = records.where((a) => a.status == AttendanceStatus.present).length;
      final daysHalf    = records.where((a) => a.status == AttendanceStatus.half).length;
      final daysAbsent  = records.where((a) => a.status == AttendanceStatus.absent).length;
      final totalDays   = daysPresent + (daysHalf * 0.5);

      final effectiveWage = records.isNotEmpty && records.first.wageAtTime > 0
          ? records.first.wageAtTime
          : labour.dailyWage;

      final grossSalary   = totalDays * effectiveWage;
      final overtimeHours = records.fold<double>(0, (acc, a) => acc + a.overtimeHours);
      final overtimePay   = overtimeHours * labour.overtimeWagePerHour;

      final advances = _paymentBox.values
          .where((p) =>
              p.labourId == labour.id &&
              p.type == PaymentType.advance &&
              p.date.year == year &&
              p.date.month == month)
          .fold<double>(0, (acc, p) => acc + p.amount);

      return {
        'labourId':     labour.id,
        'labourName':   labour.name,
        'role':         '-',
        'phone':        labour.phone,
        'dailyWage':    labour.dailyWage,
        'wageAtTime':   effectiveWage,
        'daysPresent':  daysPresent,
        'daysHalf':     daysHalf,
        'daysAbsent':   daysAbsent,
        'totalDays':    totalDays,
        'overtimeHours': overtimeHours,
        'overtimePay':  overtimePay,
        'grossSalary':  grossSalary,
        'totalAdvances': advances,
        'netPayable':   grossSalary + overtimePay - advances,
        'siteId':       records.isNotEmpty ? records.first.siteId : '',
      };
    }).toList();
  }

  // Temp labour report for a date range
  List<Map<String, dynamic>> generateTempLabourReport(int month, int year) {
    final monthStr     = '$year-${month.toString().padLeft(2, '0')}';
    final contractorId = _resolvedContractorId();
    final tempLabours  = _labourBox.values
        .where((l) =>
            l.isTemporary &&
            (l.supervisorId == supervisorId ||
                (contractorId.isNotEmpty && l.contractorId == contractorId)))
        .toList();

    return tempLabours.map((labour) {
      final records     = _attendanceBox.values
          .where((a) => a.labourId == labour.id && a.date.startsWith(monthStr))
          .toList();
      final daysPresent = records.where((a) => a.status == AttendanceStatus.present).length;
      final daysHalf    = records.where((a) => a.status == AttendanceStatus.half).length;
      final totalDays   = daysPresent + (daysHalf * 0.5);
      final effectiveWage = records.isNotEmpty && records.first.wageAtTime > 0
          ? records.first.wageAtTime
          : labour.dailyWage;
      final grossSalary = totalDays * effectiveWage;

      return {
        'labourId':   labour.id,
        'labourName': labour.name,
        'type':       'temporary',
        'dailyWage':  labour.dailyWage,
        'wageAtTime': effectiveWage,
        'daysPresent': daysPresent,
        'daysHalf':   daysHalf,
        'totalDays':  totalDays,
        'grossSalary': grossSalary,
        'siteId':     records.isNotEmpty ? records.first.siteId : '',
      };
    }).toList();
  }

  // Site-wise report
  List<Map<String, dynamic>> generateSiteWiseReport(int month, int year) {
    final monthStr     = '$year-${month.toString().padLeft(2, '0')}';
    final contractorId = _resolvedContractorId();

    final records = _attendanceBox.values
        .where((a) =>
            a.date.startsWith(monthStr) &&
            (a.contractorId == contractorId || a.supervisorId == supervisorId))
        .toList();

    final Map<String, List<Attendance>> bySite = {};
    for (final rec in records) {
      final site = rec.siteId.isNotEmpty ? rec.siteId : rec.supervisorId;
      bySite.putIfAbsent(site, () => []).add(rec);
    }

    return bySite.entries.map((entry) {
      final site         = entry.key;
      final recs         = entry.value;
      final presentCount = recs.where((r) => r.status == AttendanceStatus.present).length;
      final halfCount    = recs.where((r) => r.status == AttendanceStatus.half).length;
      final absentCount  = recs.where((r) => r.status == AttendanceStatus.absent).length;

      final totalWage = recs.fold<double>(0, (sum, r) {
        if (r.status == AttendanceStatus.present) return sum + r.wageAtTime;
        if (r.status == AttendanceStatus.half) return sum + r.wageAtTime * 0.5;
        return sum;
      });
      final otHours = recs.fold<double>(0, (sum, r) => sum + r.overtimeHours);

      return {
        'siteId':       site,
        'siteName':     site == supervisorId ? 'Your Site' : 'Site $site',
        'presentCount': presentCount,
        'halfCount':    halfCount,
        'absentCount':  absentCount,
        'totalRecords': recs.length,
        'totalWage':    totalWage,
        'overtimeHours': otHours,
      };
    }).toList()
      ..sort((a, b) => (b['totalWage'] as double).compareTo(a['totalWage'] as double));
  }

  // Labour-wise detail report
  List<Map<String, dynamic>> generateLabourWiseReport(
      String labourId, DateTime from, DateTime to) {
    final fromStr = Attendance.formatDate(from);
    final toStr   = Attendance.formatDate(to);

    final records = _attendanceBox.values
        .where((a) =>
            a.labourId == labourId &&
            a.date.compareTo(fromStr) >= 0 &&
            a.date.compareTo(toStr) <= 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return records.map((a) => {
      'date':         a.date,
      'status':       a.status.firestoreValue,
      'overtimeHours': a.overtimeHours,
      'remark':       a.remark.isNotEmpty ? a.remark : a.notes,
      'wageAtTime':   a.wageAtTime,
      'siteId':       a.siteId,
      'earned':       a.status == AttendanceStatus.present
          ? a.wageAtTime
          : a.status == AttendanceStatus.half
              ? a.wageAtTime * 0.5
              : 0.0,
    }).toList();
  }

  List<Map<String, dynamic>> generateAttendanceReport(int month, int year) {
    final monthStr     = '$year-${month.toString().padLeft(2, '0')}';
    final contractorId = _resolvedContractorId();
    final labours      = _labourBox.values
        .where((l) =>
            l.isActive &&
            (l.supervisorId == supervisorId ||
                (contractorId.isNotEmpty && l.contractorId == contractorId) ||
                l.contractorId == supervisorId))
        .toList();

    final rows = <Map<String, dynamic>>[];
    for (final labour in labours) {
      final records = _attendanceBox.values
          .where((a) => a.labourId == labour.id && a.date.startsWith(monthStr))
          .toList();
      for (final record in records) {
        rows.add({
          'labourName':   labour.name,
          'date':         record.date,
          'status':       record.status.firestoreValue,
          'overtimeHours': record.overtimeHours,
          'remark':       record.remark.isNotEmpty ? record.remark : record.notes,
          'wageAtTime':   record.wageAtTime,
          'siteId':       record.siteId,
        });
      }
    }
    rows.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return rows;
  }

  // Overall payroll (all sites + temp)
  Map<String, dynamic> generateOverallPayroll(int month, int year) {
    final salary = generateSalaryReport(month, year);
    final temp   = generateTempLabourReport(month, year);

    final regularTotal  = salary.fold<double>(0, (s, r) => s + ((r['grossSalary'] as num?) ?? 0));
    final tempTotal     = temp.fold<double>(0, (s, r) => s + ((r['grossSalary'] as num?) ?? 0));
    final totalAdvances = salary.fold<double>(0, (s, r) => s + ((r['totalAdvances'] as num?) ?? 0));
    final totalNet      = salary.fold<double>(0, (s, r) => s + ((r['netPayable'] as num?) ?? 0));

    return {
      'regularTotal':  regularTotal,
      'tempTotal':     tempTotal,
      'grandTotal':    regularTotal + tempTotal,
      'totalAdvances': totalAdvances,
      'netPayable':    totalNet,
      'regularCount':  salary.length,
      'tempCount':     temp.length,
      'regularRows':   salary,
      'tempRows':      temp,
    };
  }

  Future<void> backupAllData() async {
    final batch        = _db.batch();
    int count          = 0;
    final contractorId = _resolvedContractorId();

    for (final labour in _labourBox.values.where((l) =>
        !l.isSynced &&
        (l.supervisorId == supervisorId ||
            (contractorId.isNotEmpty && l.contractorId == contractorId) ||
            l.contractorId == supervisorId))) {
      final ref = _db.collection('labours').doc(labour.firestoreId ?? labour.id);
      batch.set(ref, labour.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    for (final att in _attendanceBox.values.where((a) =>
        !a.isSynced &&
        (a.supervisorId == supervisorId ||
            (contractorId.isNotEmpty && a.contractorId == contractorId) ||
            a.contractorId == supervisorId))) {
      final ref = _db.collection('attendance').doc(att.firestoreId ?? att.id);
      batch.set(ref, att.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    for (final payment in _paymentBox.values.where((p) =>
        !p.isSynced && p.supervisorId == supervisorId)) {
      final ref = _db.collection('payments').doc(payment.firestoreId ?? payment.id);
      batch.set(ref, payment.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    await batch.commit();
    debugPrint('Backed up $count records to Firebase');
  }

  Future<String> exportToExcel(int month, int year) async {
    final excel    = Excel.createExcel();
    final monthName = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'][month];

    final salarySheet = excel['Salary Report'];
    salarySheet.appendRow([
      TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Daily Wage'),
      TextCellValue('Wage At Time'), TextCellValue('Present'), TextCellValue('Half Day'),
      TextCellValue('Absent'), TextCellValue('Total Days'), TextCellValue('OT Hours'),
      TextCellValue('OT Pay'), TextCellValue('Gross Salary'), TextCellValue('Advances'),
      TextCellValue('Net Payable'),
    ]);
    final salaryData = generateSalaryReport(month, year);
    double tGross = 0, tAdv = 0, tNet = 0;
    for (final row in salaryData) {
      salarySheet.appendRow([
        TextCellValue(row['labourName'] as String),
        TextCellValue(row['phone'] as String),
        DoubleCellValue(row['dailyWage'] as double),
        DoubleCellValue(row['wageAtTime'] as double),
        IntCellValue(row['daysPresent'] as int),
        DoubleCellValue((row['daysHalf'] as num).toDouble()),
        IntCellValue(row['daysAbsent'] as int),
        DoubleCellValue((row['totalDays'] as num).toDouble()),
        DoubleCellValue(row['overtimeHours'] as double),
        DoubleCellValue(row['overtimePay'] as double),
        DoubleCellValue(row['grossSalary'] as double),
        DoubleCellValue(row['totalAdvances'] as double),
        DoubleCellValue(row['netPayable'] as double),
      ]);
      tGross += row['grossSalary'] as double;
      tAdv   += row['totalAdvances'] as double;
      tNet   += row['netPayable'] as double;
    }
    salarySheet.appendRow([
      TextCellValue('TOTAL'), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''),
      TextCellValue(''), TextCellValue(''),
      DoubleCellValue(tGross), DoubleCellValue(tAdv), DoubleCellValue(tNet),
    ]);

    final attSheet = excel['Attendance'];
    attSheet.appendRow([
      TextCellValue('Labour Name'), TextCellValue('Date'), TextCellValue('Status'),
      TextCellValue('OT Hours'), TextCellValue('Remark'), TextCellValue('Wage At Time'),
      TextCellValue('Site'),
    ]);
    final attData = generateAttendanceReport(month, year);
    for (final row in attData) {
      attSheet.appendRow([
        TextCellValue(row['labourName'] as String),
        TextCellValue(row['date'] as String),
        TextCellValue(row['status'] as String),
        DoubleCellValue(row['overtimeHours'] as double),
        TextCellValue((row['remark'] as String?) ?? ''),
        DoubleCellValue((row['wageAtTime'] as num?)?.toDouble() ?? 0),
        TextCellValue((row['siteId'] as String?) ?? ''),
      ]);
    }

    excel.delete('Sheet1');

    if (kIsWeb) {
      throw UnsupportedError('Excel export not supported on web');
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/report_${monthName}_$year.xlsx';
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    return path;
  }
}
