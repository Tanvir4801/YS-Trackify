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

  Future<void> fetchMonthData(int month, int year) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';

    try {
      final attSnap = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: supervisorId)
          .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
          .where('date', isLessThanOrEqualTo: '$monthStr-31')
          .get();

      for (final doc in attSnap.docs) {
        final att = Attendance.fromFirestore(doc);
        await _attendanceBox.put(att.id, att);
      }

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

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

      debugPrint('Fetched data for $monthStr');
    } catch (e) {
      debugPrint('Fetch month data failed: $e');
    }
  }

  List<Map<String, dynamic>> generateSalaryReport(int month, int year) {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final labours = _labourBox.values
        .where((l) => l.supervisorId == supervisorId && l.isActive)
        .toList();

    return labours.map((labour) {
      final records = _attendanceBox.values
          .where((a) => a.labourId == labour.id && a.date.startsWith(monthStr))
          .toList();

      final daysPresent = records.where((a) => a.status == AttendanceStatus.present).length;
      final daysHalf = records.where((a) => a.status == AttendanceStatus.half).length;
      final daysAbsent = records.where((a) => a.status == AttendanceStatus.absent).length;
      final totalDays = daysPresent + (daysHalf * 0.5);
      final grossSalary = totalDays * labour.dailyWage;

      final overtimeHours = records.fold<double>(
        0,
        (acc, a) => acc + a.overtimeHours,
      );

      final advances = _paymentBox.values
          .where((p) =>
              p.labourId == labour.id &&
              p.type == PaymentType.advance &&
              p.date.year == year &&
              p.date.month == month)
            .fold<double>(0, (acc, p) => acc + p.amount);

      final netPayable = grossSalary - advances;

      return {
        'labourId': labour.id,
        'labourName': labour.name,
        'role': '-',
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
        'daysPresent': daysPresent,
        'daysHalf': daysHalf,
        'daysAbsent': daysAbsent,
        'totalDays': totalDays,
        'overtimeHours': overtimeHours,
        'overtimePay': 0.0,
        'grossSalary': grossSalary,
        'totalAdvances': advances,
        'netPayable': netPayable,
      };
    }).toList();
  }

  List<Map<String, dynamic>> generateAttendanceReport(int month, int year) {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final labours = _labourBox.values
        .where((l) => l.supervisorId == supervisorId && l.isActive)
        .toList();

    final rows = <Map<String, dynamic>>[];
    for (final labour in labours) {
      final records = _attendanceBox.values
          .where((a) => a.labourId == labour.id && a.date.startsWith(monthStr))
          .toList();
      for (final record in records) {
        rows.add({
          'labourName': labour.name,
          'date': record.date,
          'status': record.status.firestoreValue,
          'overtimeHours': record.overtimeHours,
        });
      }
    }
    rows.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return rows;
  }

  Future<String> exportToExcel(int month, int year) async {
    final excel = Excel.createExcel();
    final monthName = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month];

    final salarySheet = excel['Salary Report'];
    salarySheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Daily Wage'),
      TextCellValue('Present'),
      TextCellValue('Half Day'),
      TextCellValue('Absent'),
      TextCellValue('Total Days'),
      TextCellValue('Gross Salary'),
      TextCellValue('Advances'),
      TextCellValue('Net Payable'),
    ]);

    final salaryData = generateSalaryReport(month, year);
    double totalGross = 0;
    double totalAdvances = 0;
    double totalNet = 0;

    for (final row in salaryData) {
      salarySheet.appendRow([
        TextCellValue(row['labourName'] as String),
        TextCellValue(row['phone'] as String),
        DoubleCellValue(row['dailyWage'] as double),
        IntCellValue(row['daysPresent'] as int),
        DoubleCellValue(row['daysHalf'] as double),
        IntCellValue(row['daysAbsent'] as int),
        DoubleCellValue(row['totalDays'] as double),
        DoubleCellValue(row['grossSalary'] as double),
        DoubleCellValue(row['totalAdvances'] as double),
        DoubleCellValue(row['netPayable'] as double),
      ]);
      totalGross += row['grossSalary'] as double;
      totalAdvances += row['totalAdvances'] as double;
      totalNet += row['netPayable'] as double;
    }

    salarySheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalGross),
      DoubleCellValue(totalAdvances),
      DoubleCellValue(totalNet),
    ]);

    final attSheet = excel['Attendance'];
    attSheet.appendRow([
      TextCellValue('Labour Name'),
      TextCellValue('Date'),
      TextCellValue('Status'),
      TextCellValue('Overtime Hours'),
    ]);

    final attData = generateAttendanceReport(month, year);
    for (final row in attData) {
      attSheet.appendRow([
        TextCellValue(row['labourName'] as String),
        TextCellValue(row['date'] as String),
        TextCellValue(row['status'] as String),
        DoubleCellValue(row['overtimeHours'] as double),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'Trackify_${monthName}_$year.xlsx';
    final filePath = '${dir.path}/$fileName';
    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath).writeAsBytesSync(fileBytes);
    }
    return filePath;
  }

  Future<void> backupAllData() async {
    final batch = _db.batch();
    int count = 0;

    for (final labour in _labourBox.values
        .where((l) => l.supervisorId == supervisorId && !l.isSynced)) {
      final ref = _db.collection('labours').doc(labour.firestoreId ?? labour.id);
      batch.set(ref, labour.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    for (final att in _attendanceBox.values
        .where((a) => a.supervisorId == supervisorId && !a.isSynced)) {
      final ref = _db.collection('attendance').doc(att.firestoreId ?? att.id);
      batch.set(ref, att.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    for (final payment in _paymentBox.values
        .where((p) => p.supervisorId == supervisorId && !p.isSynced)) {
      final ref = _db.collection('payments').doc(payment.firestoreId ?? payment.id);
      batch.set(ref, payment.toFirestore(), SetOptions(merge: true));
      count += 1;
    }

    await batch.commit();
    debugPrint('Backed up $count records to Firebase');
  }
}
