import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/house_plan_model.dart';
import '../providers/branding_provider.dart';

class HousePlanPdfService {
  static Future<File> generateBillPdf({
    required HousePlanOwner owner,
    required BrandingData branding,
  }) async {
    final pdf = pw.Document();

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    const primaryColor = PdfColor.fromInt(0xFF1E293B); // Slate dark
    const goldColor = PdfColor.fromInt(0xFFD97706); // Amber 600
    const emeraldColor = PdfColor.fromInt(0xFF059669); // Emerald 600
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    // Multi-page document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(branding, owner),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildClientDetails(owner, borderColor, lightBg),
          pw.SizedBox(height: 16),
          _buildDrawingsScopeTable(owner, primaryColor, emeraldColor, borderColor),
          if (owner.siteVisits.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildVisitsTable(owner, primaryColor, goldColor, borderColor),
          ],
          pw.SizedBox(height: 16),
          _buildFinancialSummary(owner, currencyFmt, borderColor, lightBg, emeraldColor, goldColor),
          pw.SizedBox(height: 24),
          _buildSignaturesBlock(owner, borderColor),
        ],
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final sanitizedOwner = owner.ownerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${outputDir.path}/HousePlan_Bill_${sanitizedOwner}_${owner.planNo}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(BrandingData branding, HousePlanOwner owner) {
    final companyName = branding.companyName.isNotEmpty ? branding.companyName : 'YS CONSTRUCTION';
    final tagline = branding.tagline.isNotEmpty ? branding.tagline : 'Architectural Design & Structural Engineering';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                tagline,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              if (branding.address.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(branding.address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
              if (branding.phone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Ph: ${branding.phone}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.amber300),
                ),
                child: pw.Text(
                  'ENGINEERING BILL',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (owner.planNo.isNotEmpty)
                pw.Text(
                  'Plan Ref: #${owner.planNo}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClientDetails(HousePlanOwner owner, PdfColor border, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CLIENT / OWNER DETAILS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
              pw.SizedBox(height: 3),
              pw.Text(owner.ownerName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 2),
              pw.Text('Phone: ${owner.ownerPhone.isNotEmpty ? owner.ownerPhone : "N/A"}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              if (owner.villageCity.isNotEmpty)
                pw.Text('Location: ${owner.villageCity}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PROJECT SPECIFICATIONS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
              pw.SizedBox(height: 3),
              if (owner.displaySqFt.isNotEmpty)
                pw.Text('Built-up Area: ${owner.displaySqFt}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              if (owner.serial3D.isNotEmpty)
                pw.Text('3D Ref: ${owner.serial3D}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              if (owner.supervisingEngineer.isNotEmpty)
                pw.Text('Engineer: ${owner.supervisingEngineer}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDrawingsScopeTable(
    HousePlanOwner owner,
    PdfColor primaryColor,
    PdfColor emeraldColor,
    PdfColor borderColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ENGINEERING DRAWINGS SCOPE (${owner.completedPlansCount} of ${owner.totalPlansCount} COMPLETED)',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.Text(
              '${(owner.progressPercent * 100).round()}% Completed',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: emeraldColor),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _th('#'),
                _th('Drawing Name'),
                _th('Category'),
                _th('Status'),
              ],
            ),
            ...owner.plansList.map((p) {
              return pw.TableRow(
                children: [
                  _td(p.num, align: pw.TextAlign.center),
                  _td(p.name, bold: true),
                  _td(p.category),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      p.isCompleted ? 'COMPLETED' : 'IN PROGRESS',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: p.isCompleted ? emeraldColor : PdfColors.amber800,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildVisitsTable(
    HousePlanOwner owner,
    PdfColor primaryColor,
    PdfColor goldColor,
    PdfColor borderColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SITE / HOUSE VISITS RECORD (${owner.siteVisits.length} VISITS RECORDED)',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _th('#'),
                _th('Date'),
                _th('Purpose'),
                _th('Notes / Remarks'),
                _th('Charge (Rs)', align: pw.TextAlign.right),
              ],
            ),
            ...owner.siteVisits.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final v = entry.value;
              return pw.TableRow(
                children: [
                  _td('$idx', align: pw.TextAlign.center),
                  _td(v.date),
                  _td(v.purpose, bold: true),
                  _td(v.notes.isNotEmpty ? v.notes : '-'),
                  _td(NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0).format(v.amount),
                      align: pw.TextAlign.right, bold: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFinancialSummary(
    HousePlanOwner owner,
    NumberFormat currencyFmt,
    PdfColor border,
    PdfColor bg,
    PdfColor emerald,
    PdfColor gold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('Agreed Plan Fee: ${currencyFmt.format(owner.houseAmount)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey800)),
              if (owner.siteVisits.isNotEmpty)
                pw.Text('Site Visits (${owner.siteVisits.length}): ${currencyFmt.format(owner.totalVisitsAmount)}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey800)),
              pw.Text('Total Billable: ${currencyFmt.format(owner.totalBillableAmount)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Received: ${currencyFmt.format(owner.calculatedTotalPaid)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: emerald)),
              pw.SizedBox(height: 2),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: owner.netPending <= 0 ? PdfColors.green50 : PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: owner.netPending <= 0 ? PdfColors.green300 : PdfColors.amber300),
                ),
                child: pw.Text(
                  owner.netPending <= 0
                      ? 'BALANCE: FULLY SETTLED'
                      : 'PENDING DUE: ${currencyFmt.format(owner.netPending)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: owner.netPending <= 0 ? PdfColors.green900 : PdfColors.amber900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignaturesBlock(HousePlanOwner owner, PdfColor border) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 140, height: 1, color: border),
            pw.SizedBox(height: 4),
            pw.Text('Client Acknowledgment', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 140, height: 1, color: border),
            pw.SizedBox(height: 4),
            pw.Text('Authorized Supervising Engineer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount} - Generated via YS Trackify',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      ),
    );
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
      ),
    );
  }

  static pw.Widget _td(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  /// Share bill PDF via WhatsApp or other system share sheet.
  static Future<void> shareBillPdf({
    required HousePlanOwner owner,
    required BrandingData branding,
  }) async {
    final file = await generateBillPdf(owner: owner, branding: branding);
    final text = 'Hello ${owner.ownerName}, please find attached your Engineering Plans & Site Visits Statement from ${branding.companyName.isNotEmpty ? branding.companyName : "YS Construction"}.';
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: 'Engineering Bill - ${owner.ownerName}',
    );
  }
}
