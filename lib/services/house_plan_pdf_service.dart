import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/house_plan_model.dart';
import '../providers/branding_provider.dart';

/// Generates an official, architecturally styled PDF Bill / Statement for a House Planning client.
/// Tailored specifically for physical pre-printed letterhead paper:
/// 1. Top 45mm on Page 1 is left BLANK WHITE so the pre-printed color logo/partner details show through.
/// 2. Body starts cleanly with Bill Metadata, Client Details, and Drawings Scope.
/// 3. Site Inspection & Supervision visits always appear on a SEPARATE PAGE with proper spacing.
/// 4. Signature blocks are completely removed — displaying clean financial amounts and summary only.
class HousePlanPdfService {
  // ── Executive Architectural Color Palette ──
  static const PdfColor _cSlate900 = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _cSlate800 = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _cSlate700 = PdfColor.fromInt(0xFF334155);
  static const PdfColor _cSlate600 = PdfColor.fromInt(0xFF475569);
  static const PdfColor _cSlate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _cSlate400 = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor _cSlate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _cSlate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _cSlate50  = PdfColor.fromInt(0xFFF8FAFC);

  static const PdfColor _cAmber600 = PdfColor.fromInt(0xFFD97706); // Warm gold accent
  static const PdfColor _cAmber700 = PdfColor.fromInt(0xFFB45309);
  static const PdfColor _cAmber50  = PdfColor.fromInt(0xFFFFFBEB);
  static const PdfColor _cAmber100 = PdfColor.fromInt(0xFFFEF3C7);

  static const PdfColor _cEmerald600 = PdfColor.fromInt(0xFF059669);
  static const PdfColor _cEmerald50  = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor _cCyan600    = PdfColor.fromInt(0xFF0EA5E9);
  static const PdfColor _cRed600     = PdfColor.fromInt(0xFFDC2626);

  static String _fmtCurrency(num amount) {
    return 'Rs. ${NumberFormat('#,##0', 'en_IN').format(amount.round())}';
  }

  static String _fmtDate(dynamic d) {
    if (d == null) return '-';
    if (d is DateTime) return DateFormat('dd-MM-yyyy').format(d);
    if (d is String) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) return DateFormat('dd-MM-yyyy').format(parsed);
      return d;
    }
    return '-';
  }

  /// Comprehensive text sanitization ensuring 100% printable ASCII compatibility
  /// with standard PDF Helvetica font, preventing any tofu [?] or [+] glyph boxes.
  static String _cleanPdfText(String? input) {
    if (input == null || input.isEmpty) return '';

    String text = input;

    // 1. Bullets & list markers -> clean ASCII dash with space
    text = text.replaceAll(
      RegExp(r'[\u2022\u2023\u25E6\u2043\u204C\u204D\u2219\u25CF\u25CB\u25AA\u25AB\u25A0\u25A1\u25B8\u25BA\u27A4\u279C\u2794\u204B]\s*'),
      '- ',
    );

    // 2. Checkmarks & status icons
    text = text
        .replaceAll(RegExp(r'[\u2713\u2714\u2611\u2705]'), '[OK] ')
        .replaceAll(RegExp(r'[\u2716\u2718\u274C\u2612]'), '[X] ')
        .replaceAll(RegExp(r'[\u26A0\u2757]'), '[!] ');

    // 3. Smart double and single quotes
    text = text
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u00AB\u00BB]'), '"')
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u00B4`]'), "'");

    // 4. Dashes, hyphens & horizontal bars
    text = text.replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-');

    // 5. Horizontal ellipsis
    text = text.replaceAll('\u2026', '...');

    // 6. Currency symbols
    text = text.replaceAll('\u20B9', 'Rs. ').replaceAll('\u00A3', 'GBP ').replaceAll('\u20AC', 'EUR ');

    // 7. Math & measurement symbols
    text = text
        .replaceAll('\u00D7', 'x')
        .replaceAll('\u00F7', '/')
        .replaceAll('\u00B1', '+/-')
        .replaceAll('\u00B0', ' deg')
        .replaceAll('\u00B2', '2')
        .replaceAll('\u00B3', '3')
        .replaceAll('\u00BD', '1/2')
        .replaceAll('\u00BC', '1/4')
        .replaceAll('\u00BE', '3/4')
        .replaceAll('\u2248', '~')
        .replaceAll('\u2260', '!=')
        .replaceAll('\u2264', '<=')
        .replaceAll('\u2265', '>=');

    // 8. Arrows
    text = text
        .replaceAll(RegExp(r'[\u2192\u21D2\u2799]'), '->')
        .replaceAll(RegExp(r'[\u2190\u21D0]'), '<-')
        .replaceAll(RegExp(r'[\u2194\u21D4]'), '<->');

    // 9. Zero-width spaces/formatters & non-breaking spaces & replacement chars
    text = text
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF\uFFFD]'), '')
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200A\u202F\u205F\u3000]'), ' ');

    // 10. CR LF normalization
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 11. Strictly remove any remaining non-ASCII characters that cannot be drawn by standard PDF fonts
    text = text.replaceAll(RegExp(r'[^\x20-\x7E\n\t]'), ' ');

    // 12. Normalize multiple spaces on the same line (preserve newlines)
    text = text.split('\n').map((line) => line.replaceAll(RegExp(r'[ ]{2,}'), ' ').trim()).join('\n');

    return text.trim();
  }

  /// Generates the complete, high-fidelity bill PDF.
  static Future<File> generateBillPdf({
    required HousePlanOwner owner,
    required BrandingData branding,
  }) async {
    final pdf = pw.Document();

    // Financial calculations
    final totalPlanFee = owner.houseAmount;
    final totalVisitsAmount = owner.totalVisitsAmount;
    final totalBillableAmount = owner.totalBillableAmount;
    final totalPaid = owner.calculatedTotalPaid;
    final pendingBalance = owner.netPending;

    // Client & Reference details
    final planNumber = owner.planNo.isNotEmpty ? owner.planNo : '345';
    final cleanBillRef = 'INV-${planNumber.replaceFirst(RegExp(r'^PLN-?', caseSensitive: false), '')}';
    final serial3D = owner.serial3D.isNotEmpty ? owner.serial3D : '3D-$planNumber';
    final siteLoc = [owner.ownerAddress, owner.villageCity].where((s) => s.trim().isNotEmpty).join(', ');
    final effectiveSiteLoc = siteLoc.isNotEmpty ? siteLoc : (owner.villageCity.isNotEmpty ? owner.villageCity : 'Surat');

    // Sorted drawings: Completed on top
    final sortedPlans = List<HousePlanDrawing>.from(owner.plansList)..sort((a, b) {
      final aDone = a.isCompleted ? 1 : 0;
      final bDone = b.isCompleted ? 1 : 0;
      if (aDone != bDone) return bDone - aDone;
      final aNum = int.tryParse(a.num) ?? 999;
      final bNum = int.tryParse(b.num) ?? 999;
      if (aNum != bNum) return aNum - bNum;
      return a.displayName.compareTo(b.displayName);
    });

    final hasSiteVisits = owner.siteVisits.isNotEmpty;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14 * PdfPageFormat.mm, vertical: 0),
        header: (context) {
          if (context.pageNumber > 1) {
            return _buildContinuationHeader(owner.ownerName, planNumber);
          }
          // PAGE 1: 45mm BLANK WHITE SPACE reserved for pre-printed colour letterhead paper
          return pw.SizedBox(height: 44 * PdfPageFormat.mm);
        },
        footer: (context) => _buildPageFooter(context.pageNumber, context.pagesCount),
        build: (context) => [
          // ── 1. BILL METADATA BAR (Positioned directly under the pre-printed letterhead) ──
          _buildBillMetaStrip(
            planNumber: planNumber,
          ),
          pw.SizedBox(height: 6),

          // ── 2. CLIENT / OWNER DETAILS & PROJECT SPECIFICATIONS (Side-by-Side) ──
          _buildClientAndProjectGrid(
            owner: owner,
            siteLocation: effectiveSiteLoc,
            planNumber: planNumber,
            serial3D: serial3D,
          ),
          pw.SizedBox(height: 10),

          // ── 3. SCOPE OF ENGINEERING DRAWINGS CHECKLIST TABLE ──
          _buildDrawingsScopeSection(sortedPlans),
          pw.SizedBox(height: 8),

          // ── 4. SITE INSPECTION & SUPERVISION VISITS (ON A SEPARATE PAGE) ──
          if (hasSiteVisits) ...[
            pw.NewPage(),
            _buildSiteVisitsSection(owner.siteVisits, totalVisitsAmount),
            pw.SizedBox(height: 12),
          ],

          // ── 5. PAYMENT INSTALLMENTS & ADVANCE LEDGER (IF ANY RECORDED) ──
          if (owner.payments.isNotEmpty) ...[
            _buildPaymentsLedgerSection(owner.payments),
            pw.SizedBox(height: 12),
          ],

          // ── 6. FINANCIAL BILLING SUMMARY BOX (AMOUNT ONLY, NO SIGNATURES) ──
          _buildFinancialSummaryBox(
            totalPlanFee: totalPlanFee,
            totalVisitsAmount: totalVisitsAmount,
            totalBillableAmount: totalBillableAmount,
            totalPaid: totalPaid,
            pendingBalance: pendingBalance,
            hasSiteVisits: hasSiteVisits,
            visitsCount: owner.siteVisits.length,
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final sanitizedOwner = owner.ownerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${outputDir.path}/YS_Construction_Bill_${sanitizedOwner}_$planNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. BILL METADATA STRIP (Right below letterhead, centered title, date/ref on right)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildBillMetaStrip({
    required String planNumber,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(flex: 1, child: pw.SizedBox()),
          pw.Text(
            'HOUSE PLANNING BILL',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _cSlate900,
              letterSpacing: 0.8,
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'Date: ${_fmtDate(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: _cSlate600),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    'Plan Ref: #$planNumber',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _cSlate900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. CLIENT / OWNER DETAILS & PROJECT SPECIFICATIONS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildClientAndProjectGrid({
    required HousePlanOwner owner,
    required String siteLocation,
    required String planNumber,
    required String serial3D,
  }) {
    final areaText = owner.totalSqFt > 0
        ? '${NumberFormat('#,##0').format(owner.totalSqFt)} sq.ft'
        : (owner.plotArea.isNotEmpty ? owner.plotArea : '-');

    final engineer = owner.supervisingEngineer.isNotEmpty
        ? owner.supervisingEngineer
        : 'YS_Construction';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // CLIENT / OWNER DETAILS
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLIENT / OWNER DETAILS',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _cSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _cleanPdfText(owner.ownerName.toUpperCase()),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _cSlate900,
                ),
              ),
              if (owner.ownerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Phone: ${_cleanPdfText(owner.ownerPhone)}',
                  style: const pw.TextStyle(fontSize: 8, color: _cSlate700),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                'Location: ${_cleanPdfText(siteLocation)}',
                style: const pw.TextStyle(fontSize: 8, color: _cSlate700),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // PROJECT SPECIFICATIONS
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PROJECT SPECIFICATIONS',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _cSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Built-up Area: ', style: const pw.TextStyle(fontSize: 8, color: _cSlate700)),
                  pw.Text(_cleanPdfText(areaText), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.Text('3D Ref: ', style: const pw.TextStyle(fontSize: 8, color: _cSlate700)),
                  pw.Text(_cleanPdfText(serial3D), style: const pw.TextStyle(fontSize: 8, color: _cSlate700)),
                  pw.SizedBox(width: 8),
                  pw.Text('Engineer: ', style: const pw.TextStyle(fontSize: 8, color: _cSlate700)),
                  pw.Text(_cleanPdfText(engineer), style: const pw.TextStyle(fontSize: 8, color: _cSlate700)),
                ],
              ),
              if (owner.ratePerSqFt > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Consultancy Rate: Rs. ${owner.ratePerSqFt.toStringAsFixed(0)} / sq.ft',
                  style: const pw.TextStyle(fontSize: 8, color: _cSlate700),
                ),
              ],
              if (owner.bhk.isNotEmpty || owner.facing.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  _cleanPdfText('Configuration: ${owner.bhk} | ${owner.facing} Facing (${owner.floors})'),
                  style: const pw.TextStyle(fontSize: 8, color: _cSlate700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. SCOPE OF ENGINEERING DRAWINGS CHECKLIST TABLE
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildDrawingsScopeSection(List<HousePlanDrawing> plans) {
    final completedCount = plans.where((p) => p.isCompleted).length;
    final totalCount = plans.length;
    final percent = totalCount > 0 ? ((completedCount / totalCount) * 100).round() : 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ENGINEERING DRAWINGS SCOPE ($completedCount of $totalCount COMPLETED)',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _cSlate900,
              ),
            ),
            pw.Text(
              '$percent% Completed',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: percent == 100 ? _cEmerald600 : _cAmber600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(5),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(85),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cSlate100),
              children: [
                _th('#', align: pw.TextAlign.center),
                _th('Drawing Name'),
                _th('Category'),
                _th('Status', align: pw.TextAlign.center),
              ],
            ),
            ...plans.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final isEven = idx % 2 == 0;
              final numDisplay = p.num.isNotEmpty ? p.num : idx.toString().padLeft(2, '0');
              final isCompleted = p.isCompleted;
              final statusText = isCompleted
                  ? 'COMPLETED'
                  : (p.status == 'in_progress' ? 'IN PROGRESS' : 'PENDING');
              final statusColor = isCompleted
                  ? _cEmerald600
                  : (p.status == 'in_progress' ? const PdfColor.fromInt(0xFF2563EB) : _cSlate400);

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _cSlate50 : PdfColors.white),
                children: [
                  _td(numDisplay, align: pw.TextAlign.center, bold: true, color: _cSlate600),
                  _td('$numDisplay-${p.displayName.toUpperCase()}', bold: true),
                  _td(p.category.isNotEmpty ? p.category : 'Architectural', color: _cSlate600),
                  _td(statusText, align: pw.TextAlign.center, bold: true, color: statusColor),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. SITE INSPECTION & SUPERVISION VISITS (Rendered on a separate page)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSiteVisitsSection(List<HouseSiteVisit> visits, double totalVisitsAmount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'SITE INSPECTION & SUPERVISION VISITS (${visits.length} VISITS RECORDED)',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _cSlate900,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: pw.BoxDecoration(
                color: _cAmber50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                border: pw.Border.all(color: _cAmber600, width: 0.6),
              ),
              child: pw.Text(
                'Total Visits Fee: ${_fmtCurrency(totalVisitsAmount)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _cAmber700,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FixedColumnWidth(75),
            2: pw.FlexColumnWidth(5),
            3: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cAmber100),
              children: [
                _th('#', align: pw.TextAlign.center),
                _th('Date'),
                _th('Site Inspection Purpose & Structural Notes'),
                _th('Fee Charged', align: pw.TextAlign.right),
              ],
            ),
            ...visits.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final v = entry.value;
              final isEven = idx % 2 == 0;
              final feeText = v.amount > 0 ? _fmtCurrency(v.amount) : 'Complimentary';
              final feeColor = v.amount > 0 ? _cSlate900 : _cEmerald600;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _cSlate50 : PdfColors.white),
                children: [
                  _td(idx.toString().padLeft(2, '0'), align: pw.TextAlign.center, bold: true, color: _cAmber700),
                  _td(_fmtDate(v.date), bold: true),
                  _td(v.notes.isNotEmpty ? v.notes : 'On-site structural & architectural verification'),
                  _td(feeText, align: pw.TextAlign.right, bold: true, color: feeColor),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. PAYMENT INSTALLMENTS & ADVANCE LEDGER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPaymentsLedgerSection(List<HousePlanPayment> payments) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAYMENT & ADVANCE INSTALLMENTS LEDGER (${payments.length} RECORDED)',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _cSlate900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FixedColumnWidth(75),
            2: pw.FlexColumnWidth(4),
            3: pw.FixedColumnWidth(75),
            4: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cSlate100),
              children: [
                _th('#', align: pw.TextAlign.center),
                _th('Date'),
                _th('Stage / Description'),
                _th('Mode', align: pw.TextAlign.center),
                _th('Amount', align: pw.TextAlign.right),
              ],
            ),
            ...payments.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final isEven = idx % 2 == 0;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _cSlate50 : PdfColors.white),
                children: [
                  _td(idx.toString().padLeft(2, '0'), align: pw.TextAlign.center, color: _cSlate600),
                  _td(_fmtDate(p.date)),
                  _td(p.description.isNotEmpty ? p.description : 'Advance consultancy payment'),
                  _td(p.mode.toUpperCase(), align: pw.TextAlign.center, color: _cSlate600),
                  _td(_fmtCurrency(p.amount), align: pw.TextAlign.right, bold: true, color: _cEmerald600),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. FINANCIAL BILLING SUMMARY BOX (Amounts only, no signatures)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFinancialSummaryBox({
    required double totalPlanFee,
    required double totalVisitsAmount,
    required double totalBillableAmount,
    required double totalPaid,
    required double pendingBalance,
    required bool hasSiteVisits,
    required int visitsCount,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: _cSlate200, width: 0.8),
        ),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'FINANCIAL BILLING SUMMARY',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _cSlate500,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 6),
            _summaryRow('House Planning Fee:', _fmtCurrency(totalPlanFee)),
            if (hasSiteVisits) ...[
              pw.SizedBox(height: 3),
              _summaryRow('Site Supervision ($visitsCount visits):', _fmtCurrency(totalVisitsAmount)),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(color: _cSlate200, thickness: 0.5),
            pw.SizedBox(height: 2),
            _summaryRow(
              'Gross Total Amount:',
              _fmtCurrency(totalBillableAmount),
              bold: true,
              valueColor: _cSlate900,
            ),
            pw.SizedBox(height: 3),
            _summaryRow(
              'Total Advance Received:',
              '- ${_fmtCurrency(totalPaid)}',
              bold: true,
              valueColor: _cEmerald600,
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(
                color: pendingBalance <= 0 ? _cEmerald50 : _cAmber50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                border: pw.Border.all(
                  color: pendingBalance <= 0 ? _cEmerald600 : _cAmber600,
                  width: 0.8,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    pendingBalance <= 0 ? 'NET BALANCE DUE' : 'NET BALANCE DUE',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: pendingBalance <= 0 ? _cEmerald600 : _cAmber700,
                    ),
                  ),
                  pw.Text(
                    pendingBalance <= 0 ? 'Rs. 0 (CLEARED)' : _fmtCurrency(pendingBalance),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: pendingBalance <= 0 ? _cEmerald600 : _cAmber700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: bold ? _cSlate800 : _cSlate600,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? (bold ? _cSlate900 : _cSlate700),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONTINUATION HEADER (Page 2+): Same 44mm top blank space as Page 1
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildContinuationHeader(String ownerName, String planNumber) {
    return pw.Column(
      children: [
        // Exactly same 44mm blank white space as Page 1 for physical pre-printed letterhead
        pw.SizedBox(height: 44 * PdfPageFormat.mm),
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Client: ${_cleanPdfText(ownerName.toUpperCase())}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cSlate700),
              ),
              pw.Text(
                'Plan Ref: #${_cleanPdfText(planNumber)} | Site Visits & Billing Statement',
                style: const pw.TextStyle(fontSize: 8, color: _cSlate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PAGE FOOTER
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPageFooter(int pageNumber, int pagesCount) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _cSlate200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated via YS Trackify',
            style: const pw.TextStyle(fontSize: 7, color: _cSlate400),
          ),
          pw.Text(
            'Page $pageNumber of $pagesCount',
            style: const pw.TextStyle(fontSize: 7, color: _cSlate400),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TABLE CELL HELPERS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        _cleanPdfText(text),
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _cSlate700),
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.8),
      child: pw.Text(
        _cleanPdfText(text),
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _cSlate800,
        ),
      ),
    );
  }

  /// Exports the generated Bill PDF and presents the native share/save dialog.
  static Future<void> shareBillPdf({
    required HousePlanOwner owner,
    required BrandingData branding,
  }) async {
    final file = await generateBillPdf(owner: owner, branding: branding);
    final company = branding.companyName.isNotEmpty && branding.companyName.toLowerCase() != 'trackify'
        ? branding.companyName.replaceAll('_', ' ').trim()
        : 'YS Construction';
    final text = 'Hello ${owner.ownerName}, please find attached your Engineering Plans & Site Visits Statement from $company.';
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: 'House Planning Bill - ${owner.ownerName}',
    );
  }
}
