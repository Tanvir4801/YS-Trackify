import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../models/attendance_record.dart';
import '../models/labour.dart';
import '../models/labour_report_summary.dart';

class ExportService {
  Future<ExportResult> exportBackupJson({
    required List<Labour> labours,
    required List<AttendanceRecord> attendance,
  }) async {
    final granted = await _ensureStoragePermission();
    if (!granted) {
      return const ExportResult.error('Storage permission denied');
    }

    final now = DateTime.now();
    final filename =
        'trackify_backup_${now.year}_${_two(now.month)}_${_two(now.day)}.json';

    final payload = <String, dynamic>{
      'app': 'Trackify',
      'generatedAt': now.toIso8601String(),
      'labourData': labours
          .map(
            (labour) => {
              'id': labour.id,
              'name': labour.name,
              'role': labour.role,
              'phone': labour.phoneNumber,
              'dailyWage': labour.dailyWage,
              'advance': labour.advanceAmount,
              'extraHours': labour.extraHours,
              'overtimeRate': labour.overtimeRate,
            },
          )
          .toList(),
      'attendanceData': attendance
          .map(
            (record) => {
              'id': record.id,
              'labourId': record.labourId,
              'dateKey': record.dateKey,
              'status': record.status.name,
            },
          )
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final file = await _saveTextFile(filename: filename, content: jsonString);
    return ExportResult.success(file);
  }

  Future<ExportResult> exportLabourExcel({
    required List<Labour> labours,
    required List<AttendanceRecord> attendanceRecords,
    required List<LabourReportSummary> reports,
  }) async {
    final granted = await _ensureStoragePermission();
    if (!granted) {
      return const ExportResult.error('Storage permission denied');
    }

    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != 'Labour Report') {
        excel.delete(defaultSheet);
      }
      final sheet = excel['Labour Report'];

      final header = <CellValue>[
        TextCellValue('Name'),
        TextCellValue('Role'),
        TextCellValue('Phone'),
        TextCellValue('Date'),
        TextCellValue('Status'),
        TextCellValue('Daily Wage'),
        TextCellValue('Days Worked'),
        TextCellValue('Overtime Hours'),
        TextCellValue('Overtime Pay'),
        TextCellValue('Advance'),
        TextCellValue('Total Earned'),
        TextCellValue('Final Pay'),
      ];

      sheet.appendRow(header);
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      for (var i = 0; i < header.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      final labourById = {for (final labour in labours) labour.id: labour};
      final summaryByName = {
        for (final report in reports) report.labourName: report
      };
      final records = List<AttendanceRecord>.from(attendanceRecords)
        ..sort((a, b) {
          final byDate = a.dateKey.compareTo(b.dateKey);
          if (byDate != 0) {
            return byDate;
          }
          return a.labourId.compareTo(b.labourId);
        });

      var rowIndex = 1;
      final leftAligned = CellStyle(horizontalAlign: HorizontalAlign.Left);
      final centerAligned = CellStyle(horizontalAlign: HorizontalAlign.Center);
      final rightAligned = CellStyle(horizontalAlign: HorizontalAlign.Right);

      for (final record in records) {
        final labour = labourById[record.labourId];
        if (labour == null) {
          continue;
        }

        final summary = summaryByName[labour.name];
        final daysWorked = summary?.effectiveWorkdays ?? 0;
        final totalEarned = summary?.totalEarned ?? 0;
        final advance = labour.advanceAmount;
        final overtimeHours = labour.extraHours;
        final overtimePay = labour.overtimePay;
        final finalPay = totalEarned + overtimePay - advance;

        sheet.appendRow(<CellValue>[
          TextCellValue(labour.name),
          TextCellValue(labour.role),
          TextCellValue(labour.phoneNumber),
          TextCellValue(_formatDate(record.dateKey)),
          TextCellValue(_statusText(record.status)),
          DoubleCellValue(labour.dailyWage),
          DoubleCellValue(daysWorked),
          DoubleCellValue(overtimeHours),
          DoubleCellValue(overtimePay),
          DoubleCellValue(advance),
          DoubleCellValue(totalEarned),
          DoubleCellValue(finalPay),
        ]);

        for (final col in [0, 1, 2]) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: col, rowIndex: rowIndex))
              .cellStyle = leftAligned;
        }
        for (final col in [3, 4]) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: col, rowIndex: rowIndex))
              .cellStyle = centerAligned;
        }
        for (final col in [5, 6, 7, 8, 9, 10, 11]) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: col, rowIndex: rowIndex))
              .cellStyle = rightAligned;
        }

        rowIndex += 1;
      }

      final List<int>? bytes = excel.encode();
      if (bytes == null) {
        return const ExportResult.error('Failed to generate Excel file');
      }

      final now = DateTime.now();
      final file = await _saveBytesFile(
        filename:
            'trackify_labour_report_${now.year}_${_two(now.month)}_${_two(now.day)}.xlsx',
        bytes: Uint8List.fromList(bytes),
      );
      return ExportResult.success(file);
    } catch (_) {
      return const ExportResult.error('Unable to export Excel file');
    }
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: 'Trackify export file',
      subject: 'Trackify data export',
    );
  }

  Future<File> _saveTextFile({
    required String filename,
    required String content,
  }) async {
    final dir = await _getExportDirectory();
    final path = p.join(dir.path, filename);
    final file = File(path);
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<File> _saveBytesFile({
    required String filename,
    required Uint8List bytes,
  }) async {
    final dir = await _getExportDirectory();
    final path = p.join(dir.path, filename);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        return downloads;
      }

      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Future<bool> _ensureStoragePermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      return true;
    }

    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        return true;
      }

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted || storageStatus.isLimited;
    }

    return true;
  }

  String _formatDate(String dateKey) {
    try {
      return DateFormat('dd MMM yyyy')
          .format(DateFormat('yyyy-MM-dd').parseStrict(dateKey));
    } catch (_) {
      return dateKey;
    }
  }

  String _statusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half';
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class ExportResult {
  const ExportResult._({
    required this.isSuccess,
    this.file,
    this.error,
  });

  const ExportResult.success(File file)
      : this._(
          isSuccess: true,
          file: file,
        );

  const ExportResult.error(String message)
      : this._(
          isSuccess: false,
          error: message,
        );

  final bool isSuccess;
  final File? file;
  final String? error;
}
