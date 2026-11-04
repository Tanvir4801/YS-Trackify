import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/daily_closing_report.dart';
import 'web_file_saver.dart';

// ── Colour constants (mirrors AppColors) ─────────────────────────────────────
const _navy   = PdfColor.fromInt(0xFF10141C);
const _navy2  = PdfColor.fromInt(0xFF1A2438);
const _gold   = PdfColor.fromInt(0xFFD4A437);
const _goldLt = PdfColor.fromInt(0xFFE8C468);
const _white  = PdfColors.white;
const _cream  = PdfColor.fromInt(0xFFF8F7F3);
const _border = PdfColor.fromInt(0xFFE7E5DE);
const _textP  = PdfColor.fromInt(0xFF12151B);
const _textS  = PdfColor.fromInt(0xFF6B7280);
const _green  = PdfColor.fromInt(0xFF22C55E);
const _red    = PdfColor.fromInt(0xFFEF4444);
const _amber  = PdfColor.fromInt(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────

class ReportExportService {
  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> exportPdf({
    required String labourName,
    required String labourId,
    required int month,
    required int year,
    required int daysPresent,
    required int daysThreeQuarter,
    required int daysHalf,
    required int daysQuarter,
    required int daysAbsent,
    required double totalOTHours,
    required double dailyWage,
    required double otRate,
    required double grossSalary,
    required double totalAdvances,
    required double netPayable,
    required List<Map<String, dynamic>> paymentHistory,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final bytes = await _buildPdf(
      labourName: labourName,
      labourId: labourId,
      month: month,
      year: year,
      daysPresent: daysPresent,
      daysThreeQuarter: daysThreeQuarter,
      daysHalf: daysHalf,
      daysQuarter: daysQuarter,
      daysAbsent: daysAbsent,
      totalOTHours: totalOTHours,
      dailyWage: dailyWage,
      otRate: otRate,
      grossSalary: grossSalary,
      totalAdvances: totalAdvances,
      netPayable: netPayable,
      paymentHistory: paymentHistory,
      attendanceRecords: attendanceRecords,
    );

    final safeMonth = _monthAbbr(month);
    final filename  = 'YS_${labourName.replaceAll(' ', '_')}_${safeMonth}_$year.pdf';

    await _saveOrShare(
      filename: filename,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportExcel({
    required String labourName,
    required String labourId,
    required int month,
    required int year,
    required int daysPresent,
    required int daysThreeQuarter,
    required int daysHalf,
    required int daysQuarter,
    required int daysAbsent,
    required double totalOTHours,
    required double dailyWage,
    required double otRate,
    required double grossSalary,
    required double totalAdvances,
    required double netPayable,
    required List<Map<String, dynamic>> paymentHistory,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final bytes = _buildExcel(
      labourName: labourName,
      labourId: labourId,
      month: month,
      year: year,
      daysPresent: daysPresent,
      daysThreeQuarter: daysThreeQuarter,
      daysHalf: daysHalf,
      daysQuarter: daysQuarter,
      daysAbsent: daysAbsent,
      totalOTHours: totalOTHours,
      dailyWage: dailyWage,
      otRate: otRate,
      grossSalary: grossSalary,
      totalAdvances: totalAdvances,
      netPayable: netPayable,
      paymentHistory: paymentHistory,
      attendanceRecords: attendanceRecords,
    );

    final safeMonth = _monthAbbr(month);
    final filename  = 'YS_${labourName.replaceAll(' ', '_')}_${safeMonth}_$year.xlsx';

    await _saveOrShare(
      filename: filename,
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ── Closing Report PDF ──────────────────────────────────────────────────────

  Future<void> exportClosingReportPdf(DailyClosingReport report) async {
    final bytes = await _buildClosingReportPdf(report);
    
    final safeSite = report.siteName.replaceAll(' ', '_');
    final filename  = 'YS_Closing_${safeSite}_${report.date}.pdf';

    await _saveOrShare(
      filename: filename,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  Future<List<int>> _buildClosingReportPdf(DailyClosingReport report) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final bold = pw.Font.helveticaBold();
    final reg = pw.Font.helvetica();

    final List<Map<String, dynamic>> siteBreakdowns = List<Map<String, dynamic>>.from(jsonDecode(report.siteBreakdownJson));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DAILY CLOSING REPORT', style: pw.TextStyle(font: bold, fontSize: 24, color: _white, letterSpacing: 1.5)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: ${report.date}', style: pw.TextStyle(font: reg, fontSize: 14, color: _white)),
                    pw.Text('Sites: ${siteBreakdowns.length}', style: pw.TextStyle(font: reg, fontSize: 14, color: _white)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Total Overview Summary
          pw.Text('OVERALL SUMMARY', style: pw.TextStyle(font: bold, fontSize: 16, color: _navy, letterSpacing: 1.2)),
          pw.Divider(color: _navy, thickness: 2),
          pw.SizedBox(height: 12),
          
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Attendance Total
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ATTENDANCE TOTAL', style: pw.TextStyle(font: bold, fontSize: 12, color: _textS)),
                      pw.SizedBox(height: 8),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Present:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('${report.presentCount}', style: pw.TextStyle(font: bold, fontSize: 12, color: _green))]),
                      pw.SizedBox(height: 4),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('3/4 Day:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('${report.threeQuarterCount}', style: pw.TextStyle(font: bold, fontSize: 12, color: _green))]),
                      pw.SizedBox(height: 4),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Half Day:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('${report.halfDayCount}', style: pw.TextStyle(font: bold, fontSize: 12, color: _amber))]),
                      pw.SizedBox(height: 4),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('1/4 Day:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('${report.quarterCount}', style: pw.TextStyle(font: bold, fontSize: 12, color: _amber))]),
                      pw.SizedBox(height: 4),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Absent:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('${report.absentCount}', style: pw.TextStyle(font: bold, fontSize: 12, color: _red))]),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              // Expenses Total
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EXPENSES TOTAL', style: pw.TextStyle(font: bold, fontSize: 12, color: _textS)),
                      pw.SizedBox(height: 8),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Labour Wages:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('Rs ${report.totalLabourCost.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 12))]),
                      if (report.totalMaterialCost > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Materials:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('Rs ${report.totalMaterialCost.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 12))]),
                      ],
                      if (report.totalMachineryCost > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Machinery:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('Rs ${report.totalMachineryCost.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 12))]),
                      ],
                      if (report.totalTransportCost > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Transport:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('Rs ${report.totalTransportCost.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 12))]),
                      ],
                      if (report.totalOtherCost > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Other:', style: pw.TextStyle(font: reg, fontSize: 12)), pw.Text('Rs ${report.totalOtherCost.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 12))]),
                      ],
                      pw.Divider(color: _border),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Gross Total:', style: pw.TextStyle(font: bold, fontSize: 14)), pw.Text('Rs ${report.totalExpense.toStringAsFixed(0)}', style: pw.TextStyle(font: bold, fontSize: 14, color: _navy))]),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Site Breakdown
          pw.Text('SITE-WISE BREAKDOWN', style: pw.TextStyle(font: bold, fontSize: 16, color: _navy, letterSpacing: 1.2)),
          pw.Divider(color: _navy, thickness: 2),
          pw.SizedBox(height: 12),
          
          if (siteBreakdowns.isEmpty) 
            pw.Text('No site breakdown data available.', style: pw.TextStyle(font: reg, fontStyle: pw.FontStyle.italic, color: _textS))
          else
            ...siteBreakdowns.map((siteData) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: _cream, border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${siteData['siteName'] ?? siteData['siteId']}', style: pw.TextStyle(font: bold, fontSize: 14, color: _navy)),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Labour: ${siteData['totalLabourCount'] ?? 0} (P:${siteData['presentCount'] ?? 0} H:${siteData['halfDayCount'] ?? 0} A:${siteData['absentCount'] ?? 0})', style: pw.TextStyle(font: reg, fontSize: 12)),
                              pw.Text('Wages: Rs ${((siteData['labourCost'] as num?) ?? 0).toStringAsFixed(0)}', style: pw.TextStyle(font: reg, fontSize: 12)),
                            ],
                          )
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Material: Rs ${((siteData['materialCost'] as num?) ?? 0).toStringAsFixed(0)}', style: pw.TextStyle(font: reg, fontSize: 12)),
                              pw.Text('Machinery: Rs ${((siteData['machineryCost'] as num?) ?? 0).toStringAsFixed(0)}', style: pw.TextStyle(font: reg, fontSize: 12)),
                              pw.Text('Transport: Rs ${((siteData['transportCost'] as num?) ?? 0).toStringAsFixed(0)}', style: pw.TextStyle(font: reg, fontSize: 12)),
                            ],
                          )
                        )
                      ]
                    )
                  ]
                )
              );
            }),

          pw.SizedBox(height: 32),

          // Remarks & Insights
          if (report.supervisorRemarks.isNotEmpty) ...[
            pw.Text('REMARKS', style: pw.TextStyle(font: bold, fontSize: 14, color: _navy)),
            pw.SizedBox(height: 8),
            pw.Text(report.supervisorRemarks.replaceAll(RegExp(r'[^\x00-\x7F]'), ''), style: pw.TextStyle(font: reg)),
            pw.SizedBox(height: 24),
          ],

          if (report.insights.isNotEmpty) ...[
            pw.Text('AI INSIGHTS', style: pw.TextStyle(font: bold, fontSize: 14, color: _navy)),
            pw.SizedBox(height: 8),
            ...report.insights.map((insight) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('- ', style: pw.TextStyle(font: bold, color: _gold)),
                  pw.Expanded(child: pw.Text(insight.replaceAll(RegExp(r'[^\x00-\x7F]'), ''), style: pw.TextStyle(font: reg))),
                ]
              )
            )),
          ],
        ]
      )
    );
    
    return doc.save();
  }

  // ── Save / Share (web vs mobile) ────────────────────────────────────────────

  Future<void> _saveOrShare({
    required String filename,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      await webDownloadFile(filename, bytes, mimeType);
      return;
    }

    // Mobile: write file first so we can verify it exists.
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$filename';
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);

    if (!await file.exists()) {
      throw Exception('Excel export failed: file was not created ($filePath)');
    }

    // Share to trigger OS download manager / save dialog.
    await Share.shareXFiles(
      [XFile(filePath, mimeType: mimeType)],
      subject: filename,
    );
  }


  // ── PDF Builder ─────────────────────────────────────────────────────────────

  Future<List<int>> _buildPdf({
    required String labourName,
    required String labourId,
    required int month,
    required int year,
    required int daysPresent,
    required int daysThreeQuarter,
    required int daysHalf,
    required int daysQuarter,
    required int daysAbsent,
    required double totalOTHours,
    required double dailyWage,
    required double otRate,
    required double grossSalary,
    required double totalAdvances,
    required double netPayable,
    required List<Map<String, dynamic>> paymentHistory,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final doc    = pw.Document();
    final now    = DateTime.now();
    final bold   = pw.Font.helveticaBold();
    final reg    = pw.Font.helvetica();
    final mono   = pw.Font.courier();

    final workedDays = daysPresent + daysThreeQuarter * 0.75 + daysHalf * 0.5 + daysQuarter * 0.25;
    final total      = daysPresent + daysThreeQuarter + daysHalf + daysQuarter + daysAbsent;
    final attRate    = total > 0
        ? ((workedDays / total) * 100).round()
        : 0;
    final monthLabel = '${_monthName(month)} $year';

    // ── Helper builders ─────────────────────────────────────────────────────

    pw.Widget hdr(String text) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: _navy,
      child: pw.Row(children: [
        pw.Container(width: 3, height: 12, color: _gold),
        pw.SizedBox(width: 8),
        pw.Text(text,
          style: pw.TextStyle(font: bold, fontSize: 10,
            color: _white, letterSpacing: 1.2)),
      ]),
    );

    pw.Widget rowItem(String label, String value,
        {PdfColor? color, bool large = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
              style: pw.TextStyle(font: reg, fontSize: 10, color: _textS)),
            pw.Text(value,
              style: pw.TextStyle(
                font: bold,
                fontSize: large ? 13 : 10,
                color: color ?? _textP)),
          ],
        ),
      );

    pw.Widget divider({PdfColor? color, double thick = 0.5}) =>
      pw.Container(
        height: thick, color: color ?? _border,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12));

    // ── Page ──────────────────────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _gold, width: 1.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Confidential · YS Construction · Generated ${DateFormat('dd MMM yyyy').format(now)}',
                style: pw.TextStyle(font: reg, fontSize: 7.5, color: _textS)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: _navy)),
            ],
          ),
        ),
        build: (ctx) => [

          // ── HEADER ─────────────────────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_navy, _navy2],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(children: [
                          pw.Container(
                            width: 6, height: 28,
                            decoration: pw.BoxDecoration(
                              color: _gold,
                              borderRadius: pw.BorderRadius.circular(2))),
                          pw.SizedBox(width: 10),
                          pw.Text('YS CONSTRUCTION',
                            style: pw.TextStyle(
                              font: bold, fontSize: 22,
                              color: _gold, letterSpacing: 1.5)),
                        ]),
                        pw.SizedBox(height: 6),
                        pw.Text('Labour Salary Report',
                          style: pw.TextStyle(
                            font: reg, fontSize: 12, color: _white)),
                        pw.SizedBox(height: 3),
                        pw.Text(monthLabel,
                          style: pw.TextStyle(
                            font: bold, fontSize: 13, color: _goldLt)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: _gold,
                            borderRadius: pw.BorderRadius.circular(12)),
                          alignment: pw.Alignment.center,
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('TOTAL',
                                style: pw.TextStyle(
                                  font: bold, fontSize: 7,
                                  color: _navy, letterSpacing: 1)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '₹${netPayable.toStringAsFixed(0)}',
                                style: pw.TextStyle(
                                  font: bold, fontSize: 13, color: _navy)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Container(height: 1, color: _gold.shade(0.4)),
                pw.SizedBox(height: 12),
                // Meta row
                pw.Row(children: [
                  _metaChip(bold, reg, 'Labour', labourName),
                  pw.SizedBox(width: 20),
                  _metaChip(bold, reg, 'ID', labourId.isNotEmpty ? labourId : '—'),
                  pw.SizedBox(width: 20),
                  _metaChip(bold, reg, 'Period', monthLabel),
                  pw.SizedBox(width: 20),
                  _metaChip(bold, reg, 'Generated',
                    DateFormat('dd MMM yyyy, hh:mm a').format(now)),
                ]),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── ATTENDANCE SUMMARY ──────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                hdr('ATTENDANCE SUMMARY'),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border),
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(6),
                      bottomRight: pw.Radius.circular(6))),
                  child: pw.Column(children: [
                    // Stats row
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: pw.WrapAlignment.spaceAround,
                        children: [
                          _attStat(bold, reg, '$daysPresent', 'Present', _green),
                          _attStat(bold, reg, '$daysThreeQuarter', '3/4 Day', _green),
                          _attStat(bold, reg, '$daysHalf', 'Half Day', _amber),
                          _attStat(bold, reg, '$daysQuarter', '1/4 Day', _amber),
                          _attStat(bold, reg, '$daysAbsent', 'Absent', _red),
                          _attStat(bold, reg, totalOTHours.toStringAsFixed(1), 'OT Hours', _gold),
                          _attStat(bold, reg, workedDays.toStringAsFixed(1), 'Days Worked', _navy),
                        ],
                      ),
                    ),
                    pw.Container(height: 0.5, color: _border),
                    // Progress bar row
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Attendance Rate',
                                style: pw.TextStyle(
                                  font: reg, fontSize: 9, color: _textS)),
                              pw.Text('$attRate%',
                                style: pw.TextStyle(
                                  font: bold, fontSize: 9, color: _navy)),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Stack(children: [
                            pw.Container(
                              height: 7,
                              decoration: pw.BoxDecoration(
                                color: _cream,
                                borderRadius: pw.BorderRadius.circular(4))),
                            pw.Container(
                              height: 7,
                              width: (PdfPageFormat.a4.width - 40 - 24) *
                                  (attRate / 100),
                              decoration: pw.BoxDecoration(
                                color: _gold,
                                borderRadius: pw.BorderRadius.circular(4))),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // ── SALARY BREAKDOWN ────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                hdr('SALARY BREAKDOWN'),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border),
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(6),
                      bottomRight: pw.Radius.circular(6))),
                  child: pw.Column(children: [
                    rowItem('Daily Wage', '₹${dailyWage.toStringAsFixed(0)}'),
                    divider(),
                    rowItem('Days Worked',
                      '${workedDays.toStringAsFixed(1)} days'),
                    divider(),
                    rowItem('Gross Salary',
                      '₹${grossSalary.toStringAsFixed(0)}', color: _navy),
                    if (totalOTHours > 0) ...[
                      divider(),
                      rowItem('Overtime Earnings',
                        '₹${(totalOTHours * otRate).toStringAsFixed(0)}',
                        color: _amber),
                    ],
                    divider(color: _textS, thick: 0.5),
                    rowItem('Advances Taken',
                      '-₹${totalAdvances.toStringAsFixed(0)}',
                      color: _red),
                    // Net payable highlight
                    pw.Container(
                      margin: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                      decoration: pw.BoxDecoration(
                        gradient: const pw.LinearGradient(
                          colors: [_navy, _navy2],
                          begin: pw.Alignment.topLeft,
                          end: pw.Alignment.bottomRight),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: _gold.shade(0.4))),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('NET PAYABLE',
                            style: pw.TextStyle(
                              font: bold, fontSize: 12, color: _white)),
                          pw.Text('₹${netPayable.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              font: bold, fontSize: 16,
                              color: netPayable >= 0 ? _gold : _red)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── PAYMENT HISTORY ─────────────────────────────────────────────
          if (paymentHistory.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdr('PAYMENT HISTORY'),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                    },
                    border: pw.TableBorder.all(color: _border, width: 0.5),
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: _cream),
                        children: [
                          _tCell('Date', bold, isHeader: true),
                          _tCell('Type', bold, isHeader: true),
                          _tCell('Amount', bold, isHeader: true,
                            align: pw.TextAlign.right),
                        ],
                      ),
                      // Data rows
                      ...paymentHistory.map((p) {
                        final rawDate = p['date'];
                        DateTime? date;
                        if (rawDate is DateTime) date = rawDate;
                        final type   = (p['type'] as String? ?? '').replaceAll('_', ' ');
                        final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                        return pw.TableRow(children: [
                          _tCell(
                            date != null
                                ? DateFormat('dd MMM yyyy').format(date)
                                : '—',
                            reg),
                          _tCell(type.toUpperCase(), reg),
                          _tCell('₹${amount.toStringAsFixed(0)}', bold,
                            align: pw.TextAlign.right,
                            color: type.contains('advance') ? _goldLt : _green),
                        ]);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── ATTENDANCE RECORDS ──────────────────────────────────────────
          if (attendanceRecords.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdr('DAILY ATTENDANCE RECORDS'),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                    border: pw.TableBorder.all(color: _border, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: _cream),
                        children: [
                          _tCell('Date',   bold, isHeader: true),
                          _tCell('Status', bold, isHeader: true),
                          _tCell('OT Hrs', bold, isHeader: true,
                            align: pw.TextAlign.center),
                          _tCell('Marked Via', bold, isHeader: true),
                        ],
                      ),
                      ...attendanceRecords.map((r) {
                        final date   = (r['date']   as String?) ?? '—';
                        final status = _normStatus(r['status']);
                        final ot     = (r['overtimeHours'] as num?)?.toDouble() ?? 0;
                        final via    = (r['markedVia'] as String?) ?? 'manual';
                        final sColor = status == 'Present' ? _green
                            : status == 'Absent' ? _red : _amber;
                        return pw.TableRow(children: [
                          _tCell(_fmtDate(date), reg),
                          _tCell(status, bold, color: sColor),
                          _tCell(
                            ot > 0 ? '${ot.toStringAsFixed(1)}h' : '—',
                            reg, align: pw.TextAlign.center),
                          _tCell(via, reg),
                        ]);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 24),
        ],
      ),
    );

    return doc.save();
  }

  // ── PDF helper widgets ──────────────────────────────────────────────────────

  pw.Widget _metaChip(pw.Font bold, pw.Font reg, String label, String value) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label,
        style: pw.TextStyle(font: reg, fontSize: 7.5,
          color: _white.shade(0.5))),
      pw.SizedBox(height: 2),
      pw.Text(value,
        style: pw.TextStyle(font: bold, fontSize: 9, color: _white)),
    ]);

  pw.Widget _attStat(pw.Font bold, pw.Font reg,
      String val, String label, PdfColor color) =>
    pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(val,
          style: pw.TextStyle(font: bold, fontSize: 18, color: color)),
        pw.SizedBox(height: 3),
        pw.Text(label,
          style: pw.TextStyle(font: reg, fontSize: 8, color: _textS)),
      ],
    );

  pw.Widget _vDivider() => pw.Container(
    width: 0.5, height: 40, color: _border);

  pw.Widget _tCell(String text, pw.Font font, {
    bool isHeader       = false,
    pw.TextAlign? align = pw.TextAlign.left,
    PdfColor? color,
  }) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 8.5 : 9,
          color: color ?? (isHeader ? _textP : _textS))));

  // ── Excel Builder ───────────────────────────────────────────────────────────

  List<int> _buildExcel({
    required String labourName,
    required String labourId,
    required int month,
    required int year,
    required int daysPresent,
    required int daysThreeQuarter,
    required int daysHalf,
    required int daysQuarter,
    required int daysAbsent,
    required double totalOTHours,
    required double dailyWage,
    required double otRate,
    required double grossSalary,
    required double totalAdvances,
    required double netPayable,
    required List<Map<String, dynamic>> paymentHistory,
    required List<Map<String, dynamic>> attendanceRecords,
  }) {
    final workbook = xl.Excel.createExcel();

    // ── Style helpers ─────────────────────────────────────────────────────
    xl.CellStyle navyHdr(xl.Excel wb) => xl.CellStyle(
      backgroundColorHex: xl.ExcelColor.fromHexString('#10141C'),
      fontColorHex: xl.ExcelColor.fromHexString('#D4A437'),
      bold: true, fontSize: 11,
      horizontalAlign: xl.HorizontalAlign.Left,
    );

    xl.CellStyle subHdr(xl.Excel wb) => xl.CellStyle(
      backgroundColorHex: xl.ExcelColor.fromHexString('#1A2438'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      bold: true, fontSize: 9,
      horizontalAlign: xl.HorizontalAlign.Center,
    );

    xl.CellStyle labelCell() => xl.CellStyle(
      fontColorHex: xl.ExcelColor.fromHexString('#6B7280'),
      fontSize: 9,
    );

    xl.CellStyle valueCell({bool bold = false, String? color}) =>
      xl.CellStyle(
        fontColorHex: xl.ExcelColor.fromHexString(color ?? '#12151B'),
        bold: bold, fontSize: 9,
        horizontalAlign: xl.HorizontalAlign.Right,
      );

    xl.CellStyle netCell() => xl.CellStyle(
      backgroundColorHex: xl.ExcelColor.fromHexString('#10141C'),
      fontColorHex: xl.ExcelColor.fromHexString('#D4A437'),
      bold: true, fontSize: 12,
      horizontalAlign: xl.HorizontalAlign.Right,
    );

    void setVal(xl.Sheet sheet, int row, int col, dynamic val,
        [xl.CellStyle? style]) {
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = xl.TextCellValue(val.toString());
      if (style != null) cell.cellStyle = style;
    }

    // ── Sheet 1: Summary ──────────────────────────────────────────────────
    final summary = workbook['Summary'];
    workbook.delete('Sheet1');

    int r = 0;

    // Title
    setVal(summary, r, 0, 'YS CONSTRUCTION — LABOUR SALARY REPORT',
      navyHdr(workbook));
    summary.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
    r++;

    setVal(summary, r, 0, '${_monthName(month)} $year',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('#1A2438'),
        fontColorHex: xl.ExcelColor.fromHexString('#E8C468'),
        bold: true, fontSize: 10));
    summary.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
    r += 2;

    // Labour info
    setVal(summary, r, 0, 'Labour Name', labelCell());
    setVal(summary, r, 1, labourName);
    setVal(summary, r, 2, 'Labour ID', labelCell());
    setVal(summary, r, 3, labourId);
    r++;
    setVal(summary, r, 0, 'Report Period', labelCell());
    setVal(summary, r, 1, '${_monthName(month)} $year');
    setVal(summary, r, 2, 'Generated', labelCell());
    setVal(summary, r, 3, DateFormat('dd MMM yyyy').format(DateTime.now()));
    r += 2;

    // Attendance header
    setVal(summary, r, 0, 'ATTENDANCE SUMMARY', subHdr(workbook));
    summary.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
    r++;

    for (final item in [
      ['Days Present', '$daysPresent days', '#22C55E'],
      ['Days 3/4 Day', '$daysThreeQuarter days', '#22C55E'],
      ['Days Half Day', '$daysHalf days', '#F59E0B'],
      ['Days 1/4 Day', '$daysQuarter days', '#F59E0B'],
      ['Days Absent', '$daysAbsent days', '#EF4444'],
      ['OT Hours', '${totalOTHours.toStringAsFixed(1)} hrs', '#D4A437'],
      ['Days Worked', '${(daysPresent + daysThreeQuarter * 0.75 + daysHalf * 0.5 + daysQuarter * 0.25).toStringAsFixed(1)} days', '#10141C'],
    ]) {
      setVal(summary, r, 0, item[0], labelCell());
      setVal(summary, r, 1, item[1],
        valueCell(bold: true, color: item[2]));
      r++;
    }
    r++;

    // Salary header
    setVal(summary, r, 0, 'SALARY BREAKDOWN', subHdr(workbook));
    summary.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
    r++;

    for (final item in [
      ['Daily Wage', '₹${dailyWage.toStringAsFixed(0)}', null],
      ['Gross Salary', '₹${grossSalary.toStringAsFixed(0)}', '#10141C'],
      if (totalOTHours > 0)
        ['OT Earnings', '₹${(totalOTHours * otRate).toStringAsFixed(0)}', '#F59E0B'],
      ['Advances Taken', '-₹${totalAdvances.toStringAsFixed(0)}', '#EF4444'],
    ]) {
      setVal(summary, r, 0, item[0] as String, labelCell());
      setVal(summary, r, 1, item[1] as String,
        valueCell(bold: true, color: item[2]));
      r++;
    }

    // Net payable highlight
    setVal(summary, r, 0, 'NET PAYABLE', netCell());
    setVal(summary, r, 1, '₹${netPayable.toStringAsFixed(0)}', netCell());
    summary.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
    r++;

    // Column widths
    summary.setColumnWidth(0, 22);
    summary.setColumnWidth(1, 18);
    summary.setColumnWidth(2, 16);
    summary.setColumnWidth(3, 20);

    // ── Sheet 2: Attendance ───────────────────────────────────────────────
    if (attendanceRecords.isNotEmpty) {
      final attSheet = workbook['Attendance'];
      int ar = 0;

      for (final h in ['Date', 'Status', 'OT Hours', 'Marked Via']) {
        setVal(attSheet, ar, ['Date', 'Status', 'OT Hours', 'Marked Via'].indexOf(h),
          h, subHdr(workbook));
      }
      ar++;

      for (final rec in attendanceRecords) {
        final date   = (rec['date']         as String?) ?? '—';
        final status = _normStatus(rec['status']);
        final ot     = (rec['overtimeHours'] as num?)?.toDouble() ?? 0;
        final via    = (rec['markedVia']     as String?) ?? 'manual';
        final sColor = status == 'Present' ? '#22C55E'
            : status == 'Absent' ? '#EF4444' : '#F59E0B';

        setVal(attSheet, ar, 0, _fmtDate(date));
        setVal(attSheet, ar, 1, status,
          xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString(sColor),
            bold: true, fontSize: 9));
        setVal(attSheet, ar, 2,
          ot > 0 ? '${ot.toStringAsFixed(1)}h' : '—');
        setVal(attSheet, ar, 3, via);
        ar++;
      }

      attSheet.setColumnWidth(0, 16);
      attSheet.setColumnWidth(1, 14);
      attSheet.setColumnWidth(2, 12);
      attSheet.setColumnWidth(3, 16);
    }

    // ── Sheet 3: Payments ─────────────────────────────────────────────────
    if (paymentHistory.isNotEmpty) {
      final paySheet = workbook['Payments'];
      int pr = 0;

      for (final h in ['Date', 'Type', 'Amount (₹)']) {
        setVal(paySheet, pr,
          ['Date', 'Type', 'Amount (₹)'].indexOf(h), h, subHdr(workbook));
      }
      pr++;

      for (final p in paymentHistory) {
        final rawDate = p['date'];
        DateTime? date;
        if (rawDate is DateTime) date = rawDate;
        final type   = (p['type']   as String? ?? '').replaceAll('_', ' ');
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;

        setVal(paySheet, pr, 0,
          date != null ? DateFormat('dd MMM yyyy').format(date) : '—');
        setVal(paySheet, pr, 1, type.toUpperCase());
        setVal(paySheet, pr, 2, amount.toStringAsFixed(0),
          valueCell(bold: true, color: '#10141C'));
        pr++;
      }

      paySheet.setColumnWidth(0, 18);
      paySheet.setColumnWidth(1, 16);
      paySheet.setColumnWidth(2, 16);
    }

    final encoded = workbook.encode();
    return encoded ?? [];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _monthName(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][m];

  String _monthAbbr(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];

  String _normStatus(dynamic raw) {
    final s = (raw?.toString() ?? '').toLowerCase().trim();
    if (s == 'present')                    return 'Present';
    if (s == 'absent')                     return 'Absent';
    if (s == 'half_day' || s == 'half')    return 'Half Day';
    if (s == 'pending')                    return 'Pending';
    return s.isEmpty ? '—' : s;
  }

  String _fmtDate(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}
