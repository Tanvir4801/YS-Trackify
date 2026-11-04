import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../providers/report_provider.dart';
import '../providers/branding_provider.dart';

class ReportPdfService {
  static Future<File> generate({
    required ReportSummary summary,
    required List<LabourMonthlyReport> reports,
    required BrandingData branding,
    required String supervisorName,
  }) async {
    final pdf = pw.Document();

    // 1. Fetch Logo
    Uint8List? logoBytes;
    if (branding.logoUrl != null && branding.logoUrl!.isNotEmpty) {
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(branding.logoUrl!));
        final response = await request.close();
        if (response.statusCode == 200) {
          logoBytes = await consolidateHttpClientResponseBytes(response);
        }
      } catch (e) {
        debugPrint('Error fetching logo for PDF: $e');
      }
    }

    final primaryColor = PdfColor.fromInt(branding.themeColor.value);
    
    // Check contrast for text over primaryColor
    final hsl = HSLColor.fromColor(branding.themeColor);
    final headerTextColor = hsl.lightness > 0.6 ? PdfColors.black : PdfColors.white;

    final NumberFormat currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    pw.Widget buildHeader(pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(pw.MemoryImage(logoBytes)),
                  margin: const pw.EdgeInsets.only(right: 16),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branding.companyName.isEmpty ? 'My Company' : branding.companyName,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'MONTHLY LABOUR REPORT',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      summary.monthName,
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),
        ],
      );
    }

    pw.Widget buildFooter(pw.Context context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${branding.companyName} | Monthly Labour Report - ${summary.monthName}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }

    // Prepare Site Reports for cost breakdown on Page 1
    final Map<String, SiteReport> overallSiteReports = {};
    for (var r in reports) {
      for (var s in r.siteBreakdown) {
        if (!overallSiteReports.containsKey(s.siteId)) {
          overallSiteReports[s.siteId] = SiteReport(siteId: s.siteId, siteName: s.siteName);
        }
        overallSiteReports[s.siteId]!.totalFactor += s.totalFactor;
        overallSiteReports[s.siteId]!.totalWage += s.totalWage;
        overallSiteReports[s.siteId]!.presentCount += s.presentCount;
        overallSiteReports[s.siteId]!.threeQuarterCount += s.threeQuarterCount;
        overallSiteReports[s.siteId]!.halfCount += s.halfCount;
        overallSiteReports[s.siteId]!.quarterCount += s.quarterCount;
      }
    }
    
    final Map<String, Set<String>> siteWorkers = {};
    for (var r in reports) {
      for (var s in r.siteBreakdown) {
        if (!siteWorkers.containsKey(s.siteId)) siteWorkers[s.siteId] = {};
        siteWorkers[s.siteId]!.add(r.labourId);
      }
    }

    // ── PAGE 1: COVER & SUMMARY ──
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: buildHeader,
        footer: buildFooter,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text('Supervisor: $supervisorName', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('SUMMARY OVERVIEW', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 16),
          
          // Cards
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Labour', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${summary.totalLabours + summary.tempLabours} (${summary.totalLabours} Reg, ${summary.tempLabours} Temp)'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Equivalent Days', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${summary.totalDaysWorked.toStringAsFixed(1)} days'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Gross Salary', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(currencyFmt.format(summary.totalGross)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Advances', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text('- ${currencyFmt.format(summary.totalAdvances)}', style: const pw.TextStyle(color: PdfColors.red)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET PAYABLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(currencyFmt.format(summary.totalNet), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: primaryColor)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Labour Cost (Gross)', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(currencyFmt.format(summary.totalGross)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Material Cost', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(currencyFmt.format(summary.totalMaterials)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Site Expenses', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text(currencyFmt.format(summary.totalExpenses)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL COST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(currencyFmt.format(summary.totalGross + summary.totalMaterials + summary.totalExpenses), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: primaryColor)),
                  ],
                ),
              ],
            ),
          ),
          
          if (overallSiteReports.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text('SITE-WISE COST SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Site', 'Labour Cost', 'Materials', 'Expenses', 'Total Cost'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerTextColor, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              data: [
                for (var site in overallSiteReports.values)
                  [
                    site.siteName,
                    currencyFmt.format(site.totalWage),
                    currencyFmt.format(summary.siteMaterials[site.siteId] ?? 0),
                    currencyFmt.format(summary.siteExpenses[site.siteId] ?? 0),
                    currencyFmt.format(site.totalWage + (summary.siteMaterials[site.siteId] ?? 0) + (summary.siteExpenses[site.siteId] ?? 0)),
                  ]
              ],
            ),
          ],
        ],
      ),
    );

    // ── PAGE 2: SITE ATTENDANCE SUMMARY ──
    if (overallSiteReports.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: buildHeader,
          footer: buildFooter,
          build: (context) => [
            pw.Text('SITE-WISE ATTENDANCE & COST SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Site', 'Labour', '1.0', '0.75', '0.5', '0.25', 'Eq. Days', 'Labour Cost'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerTextColor, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
              },
              data: [
                for (var site in overallSiteReports.values)
                  [
                    site.siteName,
                    '${siteWorkers[site.siteId]?.length ?? 0}',
                    '${site.presentCount}',
                    '${site.threeQuarterCount}',
                    '${site.halfCount}',
                    '${site.quarterCount}',
                    site.totalFactor.toStringAsFixed(1),
                    currencyFmt.format(site.totalWage),
                  ]
              ],
            ),
          ],
        ),
      );
    }

    // ── PAGE 3+: LABOUR-WISE REPORT ──
    for (var r in reports) {
      if (r.attendanceByDate.isEmpty) continue; // Skip if no data

      // Flatten date records
      final List<Map<String, dynamic>> flatRecords = [];
      r.attendanceByDate.forEach((date, records) {
        for (var rec in records) {
          flatRecords.add({
            'date': date,
            ...rec,
          });
        }
      });
      // Sort by date ascending
      flatRecords.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: buildHeader,
          footer: buildFooter,
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(r.labourName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('ID: ${r.labourId.substring(0, 8).toUpperCase()} | ${r.isTemp ? 'Temp' : 'Regular'} | Wage: ${currencyFmt.format(r.dailyWage)}/day', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Net Payable', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(currencyFmt.format(r.netPayable), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ]
                  )
                ]
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Site', 'Factor', 'Earned'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerTextColor, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
              data: [
                for (var rec in flatRecords)
                  [
                    rec['date'],
                    rec['siteName'] ?? rec['siteId'] ?? 'Unknown',
                    _formatStatus(rec['status']),
                    currencyFmt.format(((rec['shiftFactor'] as num?)?.toDouble() ?? _factorFromStatus(rec['status'])) * ((rec['dailyWageSnapshot'] as num?)?.toDouble() ?? r.dailyWage)),
                  ]
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Base Pay:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(currencyFmt.format(r.grossSalary), style: const pw.TextStyle(fontSize: 10)),
                        ]
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Advances:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('- ${currencyFmt.format(r.totalAdvances)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                        ]
                      ),
                      pw.SizedBox(height: 4),
                      pw.Divider(color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Net Payable:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(currencyFmt.format(r.netPayable), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        ]
                      ),
                    ]
                  )
                )
              ]
            )
          ],
        ),
      );
    }

    // Save PDF to temp directory
    final output = await getTemporaryDirectory();
    final sanitizedMonth = summary.monthName.replaceAll(' ', '_');
    final sanitizedCompany = branding.companyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String fileName = '${sanitizedCompany.isNotEmpty ? sanitizedCompany : 'Trackify'}_Monthly_Report_$sanitizedMonth.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static String _formatStatus(dynamic status) {
    if (status == 'present') return '1.0';
    if (status == 'three_quarter') return '0.75';
    if (status == 'half') return '0.5';
    if (status == 'quarter') return '0.25';
    if (status == 'absent') return '0.0';
    return status?.toString() ?? '1.0';
  }

  static double _factorFromStatus(dynamic status) {
    if (status == 'present') return 1.0;
    if (status == 'three_quarter') return 0.75;
    if (status == 'half') return 0.5;
    if (status == 'quarter') return 0.25;
    if (status == 'absent') return 0.0;
    return 1.0;
  }
}
