import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/house_plan_model.dart';
import '../providers/branding_provider.dart';

/// Generates an official, architecturally styled PDF Bill / Invoice for a House Planning client,
/// identical in design, layout, typography, colors, and structure to the Trackify Admin Web PDF.
class HousePlanPdfService {
  // ── Executive Brand Color Palette (Identical to Admin Web) ──
  static const PdfColor _cSlate900 = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _cSlate800 = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _cSlate700 = PdfColor.fromInt(0xFF334155);
  static const PdfColor _cSlate600 = PdfColor.fromInt(0xFF475569);
  static const PdfColor _cSlate400 = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor _cSlate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _cSlate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _cSlate50  = PdfColor.fromInt(0xFFF8FAFC);

  static const PdfColor _cGold     = PdfColor.fromInt(0xFFF5A623); // Primary theme gold
  static const PdfColor _cAmber600 = PdfColor.fromInt(0xFFD97706); // Warm gold accent
  static const PdfColor _cAmber700 = PdfColor.fromInt(0xFFB45309);
  static const PdfColor _cAmber50  = PdfColor.fromInt(0xFFFFFBEB);
  static const PdfColor _cAmber100 = PdfColor.fromInt(0xFFFEF3C7);

  static const PdfColor _cEmerald600 = PdfColor.fromInt(0xFF059669);
  static const PdfColor _cEmerald100 = PdfColor.fromInt(0xFFD1FAE5);
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

  /// Attempts to load the authentic high-resolution YS Construction logo from assets.
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('lib/assets/ys.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Generates the complete, high-fidelity bill PDF.
  static Future<File> generateBillPdf({
    required HousePlanOwner owner,
    required BrandingData branding,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();

    // Financial calculations
    final totalPlanFee = owner.houseAmount;
    final totalVisitsAmount = owner.totalVisitsAmount;
    final totalBillableAmount = owner.totalBillableAmount;
    final totalPaid = owner.calculatedTotalPaid;
    final pendingBalance = owner.netPending;

    // Company & Partner details
    final companyName = (branding.companyName.isNotEmpty && branding.companyName.toLowerCase() != 'trackify')
        ? branding.companyName.replaceAll('_', ' ').trim()
        : 'YS Construction';
    final tagline = branding.tagline.isNotEmpty
        ? branding.tagline
        : 'Architecture, Planner, Consultant, Interior Designer';
    final companyAddress = branding.address.isNotEmpty
        ? branding.address
        : 'Gokuldham Complex, Opp. Doodh Dairy, ANGALDHARA, Ta. Mahuva, Dist. Surat';
    final companyPhone = branding.phone.isNotEmpty ? branding.phone : '+91 80003 40720, +91 99044 45077';
    final companyEmail = branding.email.isNotEmpty ? branding.email : 'ysconstruction24@gmail.com';

    // Client & Reference details
    final planNumber = owner.planNo.isNotEmpty ? owner.planNo : 'PLN-2026-001';
    final cleanBillRef = 'INV-${planNumber.replaceFirst(RegExp(r'^PLN-?', caseSensitive: false), '')}';
    final serial3D = owner.serial3D.isNotEmpty ? owner.serial3D : '-';
    final siteLoc = [owner.ownerAddress, owner.villageCity].where((s) => s.trim().isNotEmpty).join(', ');
    final effectiveSiteLoc = siteLoc.isNotEmpty ? siteLoc : (owner.villageCity.isNotEmpty ? owner.villageCity : 'Anaval');

    // Payment Status badge
    String badgeText = 'PENDING';
    PdfColor badgeBg = _cRed600;
    if (totalBillableAmount > 0 && totalPaid >= totalBillableAmount) {
      badgeText = 'PAID IN FULL';
      badgeBg = _cEmerald600;
    } else if (totalBillableAmount > 0 && totalPaid >= totalBillableAmount * 0.5) {
      badgeText = '50%+ ADVANCE CLEARED';
      badgeBg = _cGold;
    } else if (totalPaid > 0) {
      badgeText = 'PARTIALLY PAID';
      badgeBg = _cCyan600;
    }

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
    final int scopeSectionNum = hasSiteVisits ? 3 : 2;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14 * PdfPageFormat.mm, vertical: 0),
        header: (context) {
          if (context.pageNumber > 1) {
            return _buildContinuationHeader(companyName, cleanBillRef, owner.ownerName);
          }
          return _buildFirstPageTopBar(companyName);
        },
        footer: (context) => _buildPageFooter(companyName, context.pageNumber, context.pagesCount),
        build: (context) => [
          // ── 2. MAIN BRAND HEADER BLOCK ──
          pw.SizedBox(height: 6),
          _buildBrandHeaderBlock(
            logoImage: logoImage,
            companyName: companyName,
            tagline: tagline,
            billInvoiceNo: cleanBillRef,
            badgeText: badgeText,
            badgeBg: badgeBg,
          ),
          pw.SizedBox(height: 6),

          // ── 3. ISSUED BY & BILLED TO CARDS (2 Balanced Side-by-Side Boxes) ──
          _buildClientAndConsultantCards(
            companyName: companyName,
            companyAddress: companyAddress,
            companyEmail: companyEmail,
            companyPhone: companyPhone,
            ownerName: owner.ownerName,
            ownerPhone: owner.ownerPhone,
            siteLocation: effectiveSiteLoc,
            planNumber: planNumber,
            serial3D: serial3D,
            engineerName: owner.supervisingEngineer,
          ),
          pw.SizedBox(height: 5),

          // ── 4. PROJECT & ARCHITECTURE SPECIFICATIONS BAR ──
          _buildProjectSpecificationsBar(owner, totalPlanFee),
          pw.SizedBox(height: 8),

          // ── 5. PAYMENT INSTALLMENTS & ADVANCE LEDGER ──
          _buildPaymentsLedgerSection(owner.payments),
          pw.SizedBox(height: 7),

          // ── 6. SITE INSPECTION & SUPERVISION VISITS (IF RECORDED) ──
          if (hasSiteVisits) ...[
            _buildSiteVisitsSection(owner.siteVisits, owner.supervisingEngineer),
            pw.SizedBox(height: 7),
          ],

          // ── 7. FINANCIAL BILLING SUMMARY BOX (ALIGNED RIGHT) ──
          _buildFinancialSummaryBox(
            totalPlanFee: totalPlanFee,
            totalVisitsAmount: totalVisitsAmount,
            totalBillableAmount: totalBillableAmount,
            totalPaid: totalPaid,
            pendingBalance: pendingBalance,
            hasSiteVisits: hasSiteVisits,
            visitsCount: owner.siteVisits.length,
          ),
          pw.SizedBox(height: 9),

          // ── 8. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES CHECKLIST ──
          _buildDrawingsScopeSection(sortedPlans, scopeSectionNum),
          pw.SizedBox(height: 8),

          // ── 9. TERMS & CONDITIONS BOX ──
          _buildTermsAndConditionsBox(),
          pw.SizedBox(height: 8),

          // ── 10. AUTHORIZED SIGNATURE BLOCKS ──
          _buildSignaturesBlock(owner.ownerName, companyName),
          pw.SizedBox(height: 14),
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
  // 1. TOP EXECUTIVE PARTNER RIBBON (Directly from YS Business Card)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFirstPageTopBar(String companyName) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: -14 * PdfPageFormat.mm),
      child: pw.Column(
        children: [
          pw.Container(
            height: 7 * PdfPageFormat.mm,
            color: _cSlate900,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14 * PdfPageFormat.mm),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'YOGESHWAR S. PATEL',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _cGold),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      '•   Mo. 80003 40720',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Text(
                      'SHIRISH D. PATEL',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _cGold),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      '•   Mo. 99044 45077',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(height: 0.4 * PdfPageFormat.mm, color: _cGold),
        ],
      ),
    );
  }

  // Continuation Header for Page 2+
  static pw.Widget _buildContinuationHeader(String companyName, String billRef, String ownerName) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: -14 * PdfPageFormat.mm),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        children: [
          pw.Container(
            height: 5.5 * PdfPageFormat.mm,
            color: _cSlate900,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14 * PdfPageFormat.mm),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  '${companyName.toUpperCase()} — PLANNING INVOICE & DELIVERABLES (Ref: $billRef)',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  'Client: $ownerName',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _cGold),
                ),
              ],
            ),
          ),
          pw.Container(height: 0.4 * PdfPageFormat.mm, color: _cGold),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. MAIN BRAND HEADER BLOCK
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildBrandHeaderBlock({
    required pw.MemoryImage? logoImage,
    required String companyName,
    required String tagline,
    required String billInvoiceNo,
    required String badgeText,
    required PdfColor badgeBg,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _cSlate200, width: 0.6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Authentic Logo container
              pw.Container(
                width: 24 * PdfPageFormat.mm,
                height: 24 * PdfPageFormat.mm,
                padding: const pw.EdgeInsets.all(2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: _cSlate200, width: 0.5),
                ),
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : _buildVectorEmblem(),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _cSlate900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    tagline.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cAmber600),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PLANNING INVOICE / BILL',
                style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _cSlate900),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Bill Ref: $billInvoiceNo',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cAmber600),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7.5, color: _cSlate600),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                decoration: pw.BoxDecoration(
                  color: badgeBg,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  badgeText,
                  style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clean vector fallback architectural logo if asset image is not bundled.
  static pw.Widget _buildVectorEmblem() {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('YS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _cGold)),
          pw.Text('CONSTRUCTION', style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: _cSlate600)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. CONTACT DETAILS & CLIENT INFORMATION CARDS (Side-by-Side Boxes)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildClientAndConsultantCards({
    required String companyName,
    required String companyAddress,
    required String companyEmail,
    required String companyPhone,
    required String ownerName,
    required String ownerPhone,
    required String siteLocation,
    required String planNumber,
    required String serial3D,
    required String engineerName,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- LEFT BOX: ISSUED BY (PLANNING CONSULTANT) ---
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _cSlate50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _cSlate200, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 2.5, height: 50, color: _cGold),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ISSUED BY (PLANNING CONSULTANT):',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _cSlate400),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _cSlate900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Principals: Yogeshwar S. Patel & Shirish D. Patel',
                        style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: _cAmber600),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Office: $companyAddress',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Phone: 80003 40720, 99044 45077',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Email: $companyEmail',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 8),

        // --- RIGHT BOX: BILLED TO (HOUSE OWNER / CLIENT) ---
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _cSlate50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _cSlate200, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 2.5, height: 50, color: _cGold),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED TO (HOUSE OWNER / CLIENT):',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _cSlate400),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        ownerName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _cSlate900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Phone: ${ownerPhone.isNotEmpty ? ownerPhone : "N/A"}',
                        style: const pw.TextStyle(fontSize: 7, color: _cSlate600),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Site Location: $siteLocation',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Plan Serial No: #$planNumber  •  3D Model Ref: $serial3D',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Supervising Engineer: ${engineerName.isNotEmpty ? engineerName : "Er. YS_Construction"}',
                        style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. PROJECT & ARCHITECTURE SPECIFICATIONS BAR
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProjectSpecificationsBar(HousePlanOwner owner, double totalPlanFee) {
    final rateDisplay = owner.ratePerSqFt > 0
        ? 'Rs. ${owner.ratePerSqFt.round()}/sq.ft'
        : (totalPlanFee > 0 && owner.totalSqFt > 0
            ? 'Rs. ${(totalPlanFee / owner.totalSqFt).round()}/sq.ft'
            : 'Fixed Fee');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _cSlate100,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: _cSlate200, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TOTAL BUILT-UP AREA:', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _cSlate400)),
                pw.SizedBox(height: 1),
                pw.Text(owner.displaySqFt.isNotEmpty ? owner.displaySqFt : 'N/A', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PLANNING RATE:', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _cSlate400)),
                pw.SizedBox(height: 1),
                pw.Text(rateDisplay, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CONFIGURATION & FACING:', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _cSlate400)),
                pw.SizedBox(height: 1),
                pw.Text('${owner.floors} • ${owner.bhk} • ${owner.facing} Facing', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PROJECT ENGINEER:', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _cSlate400)),
                pw.SizedBox(height: 1),
                pw.Text(owner.supervisingEngineer.isNotEmpty ? owner.supervisingEngineer : 'Er. YS_Construction', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _cAmber600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. PAYMENT INSTALLMENTS & ADVANCE LEDGER TABLE
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPaymentsLedgerSection(List<HousePlanPayment> payments) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '1. PAYMENT INSTALLMENTS & ADVANCE LEDGER',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cSlate900),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.4),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.0),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.0),
            3: const pw.FlexColumnWidth(1.6),
            4: const pw.FlexColumnWidth(1.3),
          },
          children: [
            // Gold Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cGold),
              children: [
                _th('Installment / Milestone Description'),
                _th('Date', align: pw.TextAlign.center),
                _th('Mode', align: pw.TextAlign.center),
                _th('Reference / UTR'),
                _th('Amount Received', align: pw.TextAlign.right),
              ],
            ),
            if (payments.isNotEmpty)
              ...payments.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final p = entry.value;
                final isEven = idx % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isEven ? _cSlate50 : PdfColors.white),
                  children: [
                    _td('$idx. ${p.installmentName.isNotEmpty ? p.installmentName : p.type}', bold: true),
                    _td(_fmtDate(p.date), align: pw.TextAlign.center),
                    _td(p.mode.isNotEmpty ? p.mode : 'UPI', align: pw.TextAlign.center),
                    _td(p.notes.isNotEmpty ? p.notes : '-', color: _cSlate600),
                    _td(_fmtCurrency(p.amount), align: pw.TextAlign.right, bold: true),
                  ],
                );
              })
            else
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.white),
                children: [
                  _td('No installments recorded yet. Advance payment pending.', color: _cSlate600),
                  _td('-', align: pw.TextAlign.center),
                  _td('-', align: pw.TextAlign.center),
                  _td('-', align: pw.TextAlign.center),
                  _td(_fmtCurrency(0), align: pw.TextAlign.right, bold: true),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. SITE INSPECTION & SUPERVISION VISITS TABLE
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSiteVisitsSection(List<HouseSiteVisit> visits, String engineerName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '2. SITE INSPECTION & SUPERVISION VISITS (${visits.length} VISITS)',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cSlate900),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.4),
          columnWidths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(3.2),
            3: const pw.FlexColumnWidth(1.6),
            4: const pw.FlexColumnWidth(1.2),
          },
          children: [
            // Amber-600 Gold Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cAmber600),
              children: [
                _th('#', align: pw.TextAlign.center),
                _th('Visit Date', align: pw.TextAlign.center),
                _th('Inspection Purpose / Scope of Work Inspected'),
                _th('Supervising Engineer'),
                _th('Visit Charge', align: pw.TextAlign.right),
              ],
            ),
            ...visits.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final v = entry.value;
              final isEven = idx % 2 == 0;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _cAmber50 : PdfColors.white),
                children: [
                  _td('$idx.', align: pw.TextAlign.center, bold: true, color: _cAmber600),
                  _td(_fmtDate(v.date), align: pw.TextAlign.center),
                  _td(v.purpose.isNotEmpty ? v.purpose : 'Site Inspection & Supervision', bold: true),
                  _td(engineerName.isNotEmpty ? engineerName : 'Supervising Engineer', color: _cSlate600),
                  _td(_fmtCurrency(v.amount), align: pw.TextAlign.right, bold: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. FINANCIAL BILLING SUMMARY BOX (Aligned Right)
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
          border: pw.Border.all(color: _cSlate200, width: 0.5),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(
          children: [
            _summaryRow('Base Plan Drawing Fee:', _fmtCurrency(totalPlanFee)),
            if (hasSiteVisits) ...[
              _summaryRow('Site Visits Charges ($visitsCount visits):', _fmtCurrency(totalVisitsAmount)),
              _summaryRow('Gross Total Billable Amount:', _fmtCurrency(totalBillableAmount), isBold: true, bg: _cSlate100),
            ],
            _summaryRow('Total Amount Received:', _fmtCurrency(totalPaid), isBold: true, valueColor: _cEmerald600),
            _summaryRow(
              hasSiteVisits ? 'Net Remaining Balance Due:' : 'Net Remaining Balance:',
              _fmtCurrency(pendingBalance),
              isBold: true,
              bg: pendingBalance > 0 ? _cAmber100 : _cEmerald100,
              valueColor: pendingBalance > 0 ? _cAmber700 : _cEmerald600,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool isBold = false, PdfColor? bg, PdfColor? valueColor}) {
    return pw.Container(
      color: bg ?? PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? _cSlate900 : _cSlate600,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? _cSlate900,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 8. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES CHECKLIST
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildDrawingsScopeSection(List<HousePlanDrawing> plans, int sectionNum) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$sectionNum. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES (${plans.length} DELIVERABLES)',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cSlate900),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _cSlate200, width: 0.4),
          columnWidths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(3.8),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.6),
          },
          children: [
            // Dark Executive Slate Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cSlate800),
              children: [
                _th('#', align: pw.TextAlign.center),
                _th('Engineering Plan / Drawing Deliverable'),
                _th('Discipline'),
                _th('Status / Release', align: pw.TextAlign.center),
              ],
            ),
            ...plans.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;
              final isEven = idx % 2 == 0;
              final numDisplay = p.num.isNotEmpty ? p.num : String(idx).padLeft(2, '0');
              final isCompleted = p.isCompleted;
              final statusText = isCompleted
                  ? 'COMPLETED (RELEASED)'
                  : (p.status == 'in_progress' ? 'IN PROGRESS' : 'NOT STARTED');
              final statusColor = isCompleted
                  ? _cEmerald600
                  : (p.status == 'in_progress' ? const PdfColor.fromInt(0xFF2563EB) : _cSlate400);

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _cSlate50 : PdfColors.white),
                children: [
                  _td(numDisplay, align: pw.TextAlign.center, bold: true, color: _cAmber600),
                  _td('$numDisplay-${p.displayName}', bold: true),
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
  // 9. TERMS & CONDITIONS BOX
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildTermsAndConditionsBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _cSlate50,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: _cSlate200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERMS & CONDITIONS:',
            style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: _cSlate900),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('1. Structural drawings designed per IS 456 / NBC loading & soil standards.',
                        style: const pw.TextStyle(fontSize: 6.2, color: _cSlate600)),
                    pw.SizedBox(height: 1.5),
                    pw.Text('2. Sanction plans & loan estimates certified for municipal & banking valuation.',
                        style: const pw.TextStyle(fontSize: 6.2, color: _cSlate600)),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('3. Any revisions beyond agreed architectural draft will be charged as per schedule.',
                        style: const pw.TextStyle(fontSize: 6.2, color: _cSlate600)),
                    pw.SizedBox(height: 1.5),
                    pw.Text('4. Complete drawing set & CAD soft copies released upon full plan fee settlement.',
                        style: const pw.TextStyle(fontSize: 6.2, color: _cSlate600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 10. AUTHORIZED SIGNATURE BLOCKS (2 Columns)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSignaturesBlock(String ownerName, String companyName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Client Acceptance (Left)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 140, height: 0.6, color: _cSlate400),
            pw.SizedBox(height: 3),
            pw.Text('Client Acceptance Signature', style: const pw.TextStyle(fontSize: 6.8, color: _cSlate600)),
            pw.SizedBox(height: 1),
            pw.Text('Client: $ownerName', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
            pw.SizedBox(height: 1),
            pw.Text('Date: _______________', style: const pw.TextStyle(fontSize: 6.2, color: _cSlate400)),
          ],
        ),
        // Consultant Signatory (Right)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 160, height: 0.6, color: _cSlate400),
            pw.SizedBox(height: 3),
            pw.Text('For $companyName', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _cAmber600)),
            pw.SizedBox(height: 1),
            pw.Text('Authorized Signatory & Consultant', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: _cSlate900)),
            pw.SizedBox(height: 1),
            pw.Text('(Yogeshwar S. Patel / Shirish D. Patel)', style: const pw.TextStyle(fontSize: 6.2, color: _cSlate600)),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 11. CLEAN FOOTER ON ALL PAGES
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPageFooter(String companyName, int pageNumber, int pagesCount) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _cSlate200, width: 0.4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$companyName • Architecture, Planner, Consultant, Interior Designer • Thank you for your business!',
            style: const pw.TextStyle(fontSize: 6.5, color: _cSlate400),
          ),
          pw.Text(
            'Page $pageNumber of $pagesCount',
            style: const pw.TextStyle(fontSize: 6.5, color: _cSlate400),
          ),
        ],
      ),
    );
  }

  // ── Table Cell Helpers ──
  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.0),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.2,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _cSlate900,
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
    final text = 'Hello ${owner.ownerName}, please find attached your Official Planning Invoice & Deliverables Bill from ${branding.companyName.isNotEmpty ? branding.companyName : "YS Construction"}.';
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: 'Planning Invoice & Bill - ${owner.ownerName}',
    );
  }
}
