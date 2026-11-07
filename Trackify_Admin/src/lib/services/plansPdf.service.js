import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { DEFAULT_BRANDING } from '../../context/BrandingContext';
import { OFFICIAL_YS_LOGO_DATA_URL } from '../../assets/ysLogoBase64';
import { DEFAULT_MASTER_PLANS } from './plans.service';
import { formatDate } from '../utils';

/**
 * Convert Hex Color (#RRGGBB or #RGB) to RGB array [r, g, b]
 * Guarantees 100% compatibility across all versions of jsPDF
 */
function hexToRgb(hex) {
  if (!hex || typeof hex !== 'string') return [245, 166, 35]; // Default Gold (#F5A623)
  const cleaned = hex.replace('#', '').trim();
  if (cleaned.length === 3) {
    return [
      parseInt(cleaned[0] + cleaned[0], 16),
      parseInt(cleaned[1] + cleaned[1], 16),
      parseInt(cleaned[2] + cleaned[2], 16),
    ];
  }
  if (cleaned.length === 6) {
    return [
      parseInt(cleaned.substring(0, 2), 16),
      parseInt(cleaned.substring(2, 4), 16),
      parseInt(cleaned.substring(4, 6), 16),
    ];
  }
  return [245, 166, 35];
}

/**
 * Format currency safely for PDF (avoids encoding issues with unicode rupee symbol in jsPDF)
 */
function formatPdfCurrency(amount) {
  const num = Number(amount) || 0;
  return 'Rs. ' + num.toLocaleString('en-IN');
}

/**
 * Comprehensive text sanitization ensuring 100% printable ASCII compatibility
 * with standard PDF Helvetica font, preventing any tofu [?] or [+] glyph boxes.
 */
export function cleanPdfText(input) {
  if (!input) return '';
  let text = String(input);

  // 1. Bullets & list markers -> clean ASCII dash with space
  text = text.replace(/[\u2022\u2023\u25E6\u2043\u204C\u204D\u2219\u25CF\u25CB\u25AA\u25AB\u25A0\u25A1\u25B8\u25BA\u27A4\u279C\u2794\u204B]\s*/g, '- ');

  // 2. Checkmarks & status icons
  text = text
    .replace(/[\u2713\u2714\u2611\u2705]/g, '[OK] ')
    .replace(/[\u2716\u2718\u274C\u2612]/g, '[X] ')
    .replace(/[\u26A0\u2757]/g, '[!] ');

  // 3. Smart double and single quotes
  text = text
    .replace(/[\u201C\u201D\u201E\u201F\u00AB\u00BB]/g, '"')
    .replace(/[\u2018\u2019\u201A\u201B\u00B4`]/g, "'");

  // 4. Dashes, hyphens & horizontal bars
  text = text.replace(/[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]/g, '-');

  // 5. Horizontal ellipsis
  text = text.replace(/\u2026/g, '...');

  // 6. Currency symbols
  text = text.replace(/\u20B9/g, 'Rs. ').replace(/\u00A3/g, 'GBP ').replace(/\u20AC/g, 'EUR ');

  // 7. Math & measurement symbols
  text = text
    .replace(/\u00D7/g, 'x')
    .replace(/\u00F7/g, '/')
    .replace(/\u00B1/g, '+/-')
    .replace(/\u00B0/g, ' deg')
    .replace(/\u00B2/g, '2')
    .replace(/\u00B3/g, '3')
    .replace(/\u00BD/g, '1/2')
    .replace(/\u00BC/g, '1/4')
    .replace(/\u00BE/g, '3/4')
    .replace(/\u2248/g, '~')
    .replace(/\u2260/g, '!=')
    .replace(/\u2264/g, '<=')
    .replace(/\u2265/g, '>=');

  // 8. Arrows
  text = text
    .replace(/[\u2192\u21D2\u2799]/g, '->')
    .replace(/[\u2190\u21D0]/g, '<-')
    .replace(/[\u2194\u21D4]/g, '<->');

  // 9. Zero-width spaces/formatters & non-breaking spaces & replacement chars
  text = text
    .replace(/[\u200B\u200C\u200D\uFEFF\uFFFD]/g, '')
    .replace(/[\u00A0\u2000-\u200A\u202F\u205F\u3000]/g, ' ');

  // 10. CR LF normalization
  text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // 11. Strictly remove any remaining non-ASCII characters that cannot be drawn by standard PDF fonts
  text = text.replace(/[^\x20-\x7E\n\t]/g, ' ');

  // 12. Normalize multiple spaces on the same line (preserve newlines)
  text = text.split('\n').map((line) => line.replace(/[ ]{2,}/g, ' ').trim()).join('\n');

  return text.trim();
}

/**
 * Parses natural dimensions from a base64 DataURL
 */
function parseDataUrlDimensions(dataUrl) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      resolve({
        dataUrl,
        width: img.naturalWidth || img.width || 100,
        height: img.naturalHeight || img.height || 100,
      });
    };
    img.onerror = () => resolve(null);
    img.src = dataUrl;
  });
}

/**
 * Robust logo loader with multi-layer fallback:
 * 1. If base64 data URL provided directly, return immediately.
 * 2. Check localStorage for user's uploaded logo data URL.
 * 3. Fetch via fetch() -> blob -> FileReader (bypasses canvas taint on Firebase Storage).
 * 4. Image element with crossOrigin Anonymous + canvas fallback.
 * 5. Ultimate fallback: Official YS Construction Logo in high-resolution base64.
 */
async function loadLogoDataUrl(url, dataUrlFallback) {
  // Layer 1: Direct base64 DataURL passed in
  if (dataUrlFallback && typeof dataUrlFallback === 'string' && dataUrlFallback.startsWith('data:image/')) {
    const parsed = await parseDataUrlDimensions(dataUrlFallback);
    if (parsed) return parsed;
  }
  if (typeof url === 'string' && url.startsWith('data:image/')) {
    return await parseDataUrlDimensions(url);
  }

  // Layer 2: Check localStorage for cached uploaded logo
  try {
    if (typeof window !== 'undefined') {
      const cached = localStorage.getItem('trackify_brand_logo_data_url');
      if (cached && cached.startsWith('data:image/')) {
        const parsed = await parseDataUrlDimensions(cached);
        if (parsed) return parsed;
      }
    }
  } catch (_) {}

  // Layer 3: Fetch as Blob (avoids canvas taint issues on cross-origin Firebase Storage)
  if (url && typeof url === 'string') {
    try {
      const res = await fetch(url, { mode: 'cors' });
      if (res.ok) {
        const blob = await res.blob();
        const b64 = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
        if (b64) {
          const parsed = await parseDataUrlDimensions(b64);
          if (parsed) {
            try {
              if (typeof window !== 'undefined') {
                localStorage.setItem('trackify_brand_logo_data_url', b64);
              }
            } catch (_) {}
            return parsed;
          }
        }
      }
    } catch (err) {
      console.warn('Fetch blob for logo failed, falling back:', err);
    }

    // Layer 4: Image element with crossOrigin
    try {
      const img = new Image();
      img.crossOrigin = 'Anonymous';
      img.src = url;
      await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
        setTimeout(() => reject(new Error('Logo image load timed out')), 2500);
      });

      const canvas = document.createElement('canvas');
      canvas.width = img.naturalWidth || img.width;
      canvas.height = img.naturalHeight || img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const b64 = canvas.toDataURL('image/png');
      try {
        if (typeof window !== 'undefined') {
          localStorage.setItem('trackify_brand_logo_data_url', b64);
        }
      } catch (_) {}
      return {
        dataUrl: b64,
        width: canvas.width,
        height: canvas.height,
      };
    } catch (canvasErr) {
      console.warn('Canvas toDataURL failed:', canvasErr);
    }
  }

  // Layer 5: Authentic Official YS Construction Brand Logo (High-Res)
  if (OFFICIAL_YS_LOGO_DATA_URL) {
    const parsed = await parseDataUrlDimensions(OFFICIAL_YS_LOGO_DATA_URL);
    if (parsed) return parsed;
  }

  return null;
}

/**
 * Draws the authentic Architectural Roof, Chimney, 4-Pane Window,
 * and Curved Foundation Arc Logo directly from the YS Construction Business Card.
 */
function drawBusinessCardVectorLogo(doc, x, y, width, height) {
  // Clean white card background with subtle border
  doc.setFillColor(255, 255, 255);
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(x, y, width, height, 2, 2, 'FD');

  const centerX = x + width / 2;
  const topY = y + 3.8;

  // Gold stroke for architectural gable roof
  doc.setDrawColor(245, 166, 35);
  doc.setLineWidth(0.8);

  // Left roof slope
  doc.line(centerX, topY, x + 3.5, y + 13.5);
  // Right roof slope
  doc.line(centerX, topY, x + width - 3.5, y + 13.5);

  // Chimney / Tower on right
  doc.setFillColor(245, 166, 35);
  doc.rect(centerX + 3.5, topY + 1.2, 2.2, 4.2, 'F');

  // 4-Pane Square Window in Center
  const winSize = 1.7;
  const winGap = 0.5;
  const winX = centerX - winSize - winGap / 2;
  const winY = topY + 4.8;

  doc.rect(winX, winY, winSize, winSize, 'F');
  doc.rect(winX + winSize + winGap, winY, winSize, winSize, 'F');
  doc.rect(winX, winY + winSize + winGap, winSize, winSize, 'F');
  doc.rect(winX + winSize + winGap, winY + winSize + winGap, winSize, winSize, 'F');

  // Curved Foundation Arc (from business card)
  doc.setLineWidth(0.7);
  const arcY = y + 16.5;
  const arcLeft = x + 3;
  const arcRight = x + width - 3;
  const arcMid = centerX;
  const arcPeak = y + 14.8;

  doc.line(arcLeft, arcY, arcMid - 3.5, arcPeak + 0.5);
  doc.line(arcMid - 3.5, arcPeak + 0.5, arcMid, arcPeak);
  doc.line(arcMid, arcPeak, arcMid + 3.5, arcPeak + 0.5);
  doc.line(arcMid + 3.5, arcPeak + 0.5, arcRight, arcY);

  // Brand Name underneath
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.5);
  doc.setTextColor(245, 166, 35);
  doc.text('XYZ Construction', centerX, y + 21.2, { align: 'center' });
}

/**
 * Generates an official, architecturally styled PDF Bill / Invoice for a House Planning client.
 *
 * @param {Object} params
 * @param {Object} params.owner - The house plan client record
 * @param {Object} params.branding - Current branding configuration from BrandingContext
 * @param {boolean} [params.saveImmediately=true] - Whether to trigger browser download
 * @returns {Promise<jsPDF>}
 */
export async function generateHousePlanInvoicePDF({
  owner,
  branding = DEFAULT_BRANDING,
  saveImmediately = true,
}) {
  if (!owner) throw new Error('Owner data is required to generate PDF bill');

  let effectiveBranding = { ...DEFAULT_BRANDING, ...(branding || {}) };

  // Check localStorage for uploaded logo if not in effectiveBranding
  if (typeof window !== 'undefined' && !effectiveBranding.logoDataUrl) {
    const cached = localStorage.getItem('trackify_brand_logo_data_url');
    if (cached) effectiveBranding.logoDataUrl = cached;
  }

  // If branding passed from context is missing uploaded logo, query contractor Firestore doc directly
  if (!effectiveBranding.logoDataUrl && owner.contractorId) {
    try {
      const contractorSnap = await getDoc(doc(db, 'contractors', owner.contractorId));
      if (contractorSnap.exists() && contractorSnap.data()?.branding) {
        effectiveBranding = {
          ...effectiveBranding,
          ...contractorSnap.data().branding,
        };
      }
    } catch (e) {
      console.warn('Could not fetch contractor branding directly:', e);
    }
  }

  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4',
  });

  const pageWidth = doc.internal.pageSize.getWidth(); // 210mm
  const pageHeight = doc.internal.pageSize.getHeight(); // 297mm
  const margin = 14;

  const themeHex = effectiveBranding?.themeColor || '#F5A623';
  const rgbTheme = hexToRgb(themeHex);

  // Business Card Details Fallbacks
  let rawCompanyName = effectiveBranding?.companyName || '';
  if (!rawCompanyName || rawCompanyName.toLowerCase() === 'trackify') {
    rawCompanyName = 'XYZ Construction';
  }
  const companyName = rawCompanyName.replace(/_/g, ' ').trim();
  const tagline = effectiveBranding?.tagline || 'Civil Engineering & Infrastructure Contractors';
  const companyAddress = effectiveBranding?.address || 'Corporate Tower, Tech Park Zone, Sector 4, Metro City';
  const companyPhone = effectiveBranding?.phone || '+91 98765 00000';
  const companyEmail = effectiveBranding?.email || 'contact@xyz-construction.demo';
  const gstNumber = effectiveBranding?.gstNumber || '';

  const ownerName = owner.ownerName || 'Client';
  const planNumber = owner.planNumber || 'PLN-2026-001';
  const serialNumber3D = owner.serialNumber3D || '-';
  const billInvoiceNo = `INV-${planNumber.replace(/^PLN-/i, '')}`;
  const totalPlanFee = Number(owner.houseAmount) || 0;
  const payments = Array.isArray(owner.payments) ? owner.payments : [];
  const siteVisits = Array.isArray(owner.siteVisits) ? owner.siteVisits : [];

  // Compute site visits charges and total billable amount
  const totalVisitsAmount = siteVisits.reduce((sum, v) => sum + (Number(v.amount) || 0), 0);
  const totalBillableAmount = totalPlanFee + totalVisitsAmount;

  // Always compute total paid directly from payments ledger to ensure 100% calculation accuracy
  const calculatedTotalPaid = payments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const totalPaid = payments.length > 0 ? calculatedTotalPaid : (Number(owner.totalPaid) || 0);
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  // Use owner's plansList if populated; otherwise fallback to the exact 21 default engineering plans
  const rawPlans = Array.isArray(owner.plansList) && owner.plansList.length > 0 ? owner.plansList : DEFAULT_MASTER_PLANS;

  // ─────────────────────────────────────────────────────────────────────────
  // 1 & 2. PRE-PRINTED LETTERHEAD BLANK HEADER & BILL METADATA STRIP
  // ─────────────────────────────────────────────────────────────────────────
  // Top 44mm is left BLANK WHITE for the physical pre-printed colour letterhead
  const billTopY = 44;

  // Title: Centered bold small title
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.setTextColor(15, 23, 42); // slate-900
  doc.text('HOUSE PLANNING BILL', pageWidth / 2, billTopY, { align: 'center' });

  // Right Header: Date & Plan Ref
  const rightX = pageWidth - margin;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(71, 85, 105);
  doc.text(`Date: ${formatDate(new Date())}`, rightX, billTopY - 3.5, { align: 'right' });

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(15, 23, 42);
  doc.text(`Plan Ref: #${planNumber}`, rightX, billTopY + 0.5, { align: 'right' });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. CONTACT DETAILS & CLIENT INFORMATION CARDS (Auto-Wrapping & Dynamic Height)
  // ─────────────────────────────────────────────────────────────────────────
  const infoTopY = billTopY + 6;
  const colWidth = (pageWidth - margin * 2 - 6) / 2; // 88mm
  const innerPad = 6;
  const maxTextW = colWidth - innerPad - 4; // 78mm inner text width

  // Auto-wrap office address for Left Box (Issued By)
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.2);
  const leftAddressLines = doc.splitTextToSize(`Office: ${companyAddress}`, maxTextW);

  // Auto-wrap full site address for Right Box (Billed To)
  const clientFullAddr = [
    owner.ownerAddress,
    owner.city || owner.town,
  ].filter(Boolean).join(', ') || owner.city || owner.town || owner.ownerAddress || 'Anaval';
  const rightSiteLines = doc.splitTextToSize(`Site Location: ${clientFullAddr}`, maxTextW);

  // Dynamic box height calculation: ensures text NEVER spills out of container
  const leftTotalH = 6 + 5 + 4.5 + (leftAddressLines.length * 3.8) + 3.8 + 3.8 + 4.5;
  const rightTotalH = 6 + 5 + 4.5 + (rightSiteLines.length * 3.8) + 3.8 + 3.8 + 4.5;
  const containerHeight = Math.max(38, Math.max(leftTotalH, rightTotalH));

  // --- DRAW LEFT BOX: ISSUED BY (PLANNING CONSULTANT) ---
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(margin, infoTopY, colWidth, containerHeight, 2, 2, 'FD');

  // Solid left accent bar
  doc.setFillColor(...rgbTheme);
  doc.rect(margin, infoTopY, 2.5, containerHeight, 'F');

  let curLeftY = infoTopY + 5.5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(100, 116, 139);
  doc.text('ISSUED BY (PLANNING CONSULTANT):', margin + innerPad, curLeftY);

  curLeftY += 5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.setTextColor(15, 23, 42);
  doc.text(companyName, margin + innerPad, curLeftY);

  curLeftY += 4.5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.2);
  doc.setTextColor(217, 119, 6); // amber/gold
  doc.text('Principals: Yogeshwar S. Patel & Shirish D. Patel', margin + innerPad, curLeftY);

  curLeftY += 4.2;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.2);
  doc.setTextColor(71, 85, 105);
  leftAddressLines.forEach((line) => {
    doc.text(line, margin + innerPad, curLeftY);
    curLeftY += 3.8;
  });

  doc.text(`Phone: 80003 40720, 99044 45077`, margin + innerPad, curLeftY);
  curLeftY += 3.8;
  doc.text(`Email: ${companyEmail}`, margin + innerPad, curLeftY);

  // --- DRAW RIGHT BOX: BILLED TO (HOUSE OWNER / CLIENT) ---
  const clientBoxX = margin + colWidth + 6;
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(clientBoxX, infoTopY, colWidth, containerHeight, 2, 2, 'FD');

  // Solid left accent bar
  doc.setFillColor(...rgbTheme);
  doc.rect(clientBoxX, infoTopY, 2.5, containerHeight, 'F');

  let curRightY = infoTopY + 5.5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(100, 116, 139);
  doc.text('BILLED TO (HOUSE OWNER / CLIENT):', clientBoxX + innerPad, curRightY);

  curRightY += 5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.setTextColor(15, 23, 42);
  doc.text(ownerName.toUpperCase(), clientBoxX + innerPad, curRightY);

  curRightY += 4.5;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(71, 85, 105);
  doc.text(`Phone: ${owner.ownerPhone || 'N/A'}`, clientBoxX + innerPad, curRightY);

  curRightY += 4.2;
  doc.setFontSize(7.2);
  rightSiteLines.forEach((line) => {
    doc.text(line, clientBoxX + innerPad, curRightY);
    curRightY += 3.8;
  });

  doc.text(`Plan Serial No: ${planNumber}  |  3D Model Ref: ${serialNumber3D}`, clientBoxX + innerPad, curRightY);
  curRightY += 3.8;
  doc.text(`Supervising Engineer: ${owner.engineerName || 'Er. Structural Consultant'}`, clientBoxX + innerPad, curRightY);

  // ─────────────────────────────────────────────────────────────────────────
  // 4. PROJECT & ARCHITECTURE SPECIFICATIONS BAR
  // ─────────────────────────────────────────────────────────────────────────
  const specY = infoTopY + containerHeight + 3.5;
  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(margin, specY, pageWidth - margin * 2, 10.5, 2, 2, 'FD');

  const specColWidth = (pageWidth - margin * 2) / 4;
  doc.setFontSize(7);

  // Spec 1: Total Built-up Area
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('TOTAL BUILT-UP AREA:', margin + 4, specY + 4.2);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  const builtUpDisplay = (Number(owner.totalSqFt) > 0 || Number(owner.plotAreaSqFt) > 0)
    ? `${Number(owner.totalSqFt || owner.plotAreaSqFt).toLocaleString('en-IN')} sq.ft`
    : 'N/A';
  doc.text(builtUpDisplay, margin + 4, specY + 8.2);

  // Spec 2: Rate per sq.ft
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('PLANNING RATE:', margin + specColWidth + 4, specY + 4.2);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  const rateDisplay = owner.ratePerSqFt ? `Rs. ${owner.ratePerSqFt}/sq.ft` : totalPlanFee && owner.totalSqFt ? `Rs. ${Math.round(totalPlanFee / owner.totalSqFt)}/sq.ft` : 'Fixed Fee';
  doc.text(rateDisplay, margin + specColWidth + 4, specY + 8.2);

  // Spec 3: Structural Specs
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('CONFIGURATION & FACING:', margin + specColWidth * 2 + 4, specY + 4.2);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  doc.text(`${owner.floors || 'G+1'} | ${owner.bhk || '3 BHK'} | ${owner.facing || 'East'}`, margin + specColWidth * 2 + 4, specY + 8.2);

  // Spec 4: Engineer In-Charge
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('PROJECT ENGINEER:', margin + specColWidth * 3 + 4, specY + 4.2);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(217, 119, 6);
  doc.text(owner.engineerName || 'Er. Structural Consultant', margin + specColWidth * 3 + 4, specY + 8.2);

  // ─────────────────────────────────────────────────────────────────────────
  // 5. PAYMENTS & ADVANCE INSTALLMENTS LEDGER TABLE
  // ─────────────────────────────────────────────────────────────────────────
  const paymentSectionY = specY + 14;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(15, 23, 42);
  doc.text('1. PAYMENT INSTALLMENTS & ADVANCE LEDGER', margin, paymentSectionY);

  const paymentHeaders = ['Installment / Milestone Description', 'Date', 'Mode', 'Reference / UTR', 'Amount Received'];

  let paymentRows = [];
  if (payments.length > 0) {
    paymentRows = payments.map((p, idx) => [
      `${idx + 1}. ${cleanPdfText(p.installmentName || p.type || 'Part Payment')}`,
      p.date ? formatDate(p.date) : '-',
      cleanPdfText(p.mode || 'UPI'),
      cleanPdfText(p.referenceNo || p.notes || '-'),
      formatPdfCurrency(p.amount),
    ]);
  } else {
    paymentRows = [
      ['No installments recorded yet. Advance payment pending.', '-', '-', '-', formatPdfCurrency(0)],
    ];
  }

  autoTable(doc, {
    startY: paymentSectionY + 2.5,
    head: [paymentHeaders],
    body: paymentRows,
    theme: 'grid',
    headStyles: {
      fillColor: rgbTheme,
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 8,
      cellPadding: 2.3,
    },
    styles: {
      fontSize: 7.8,
      cellPadding: 2,
      textColor: '#1E293B',
      lineColor: '#E2E8F0',
      lineWidth: 0.2,
    },
    columnStyles: {
      0: { cellWidth: 70, fontStyle: 'bold' },
      1: { cellWidth: 26, halign: 'center' },
      2: { cellWidth: 22, halign: 'center' },
      3: { cellWidth: 36, textColor: '#64748B' },
      4: { cellWidth: 28, halign: 'right', fontStyle: 'bold' },
    },
    alternateRowStyles: {
      fillColor: '#F8FAFC',
    },
    margin: { left: margin, right: margin, top: 16, bottom: 16 },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5B. SITE INSPECTION & SUPERVISION VISITS LEDGER TABLE (IF ANY RECORDED)
  // ─────────────────────────────────────────────────────────────────────────
  let nextSectionNum = 2;

  if (siteVisits.length > 0) {
    doc.addPage();
    const visitsSectionY = 53;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.setTextColor(15, 23, 42);
    doc.text(`2. SITE INSPECTION & SUPERVISION VISITS (${siteVisits.length} VISITS)`, margin, visitsSectionY);

    const visitHeaders = ['#', 'Visit Date', 'Inspection Purpose / Scope of Work Inspected', 'Supervising Engineer', 'Visit Charge'];
    const visitRows = siteVisits.map((v, idx) => [
      `${idx + 1}.`,
      v.date ? formatDate(v.date) : '-',
      cleanPdfText(v.notes || v.purpose || 'Site Inspection & Supervision'),
      cleanPdfText(v.visitedBy || owner.engineerName || 'Supervising Engineer'),
      formatPdfCurrency(v.amount),
    ]);

    autoTable(doc, {
      startY: visitsSectionY + 2.5,
      head: [visitHeaders],
      body: visitRows,
      theme: 'grid',
      headStyles: {
        fillColor: [217, 119, 6], // Amber-600 Gold for site visits
        textColor: [255, 255, 255],
        fontStyle: 'bold',
        fontSize: 8,
        cellPadding: 2.2,
      },
      styles: {
        fontSize: 7.6,
        cellPadding: 2,
        textColor: '#1E293B',
        lineColor: '#E2E8F0',
        lineWidth: 0.2,
      },
      columnStyles: {
        0: { cellWidth: 10, halign: 'center', fontStyle: 'bold', textColor: '#D97706' },
        1: { cellWidth: 26, halign: 'center' },
        2: { cellWidth: 80, fontStyle: 'bold' },
        3: { cellWidth: 38, textColor: '#64748B' },
        4: { cellWidth: 28, halign: 'right', fontStyle: 'bold' },
      },
      alternateRowStyles: {
        fillColor: '#FFFBEB', // subtle warm amber alternate
      },
      margin: { left: margin, right: margin, top: 16, bottom: 16 },
    });

    nextSectionNum = 3;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. FINANCIAL BILLING SUMMARY BOX
  // ─────────────────────────────────────────────────────────────────────────
  const summaryStartY = doc.lastAutoTable.finalY + 3;
  const summaryBoxWidth = siteVisits.length > 0 ? 94 : 84;
  const summaryBoxX = pageWidth - margin - summaryBoxWidth;

  let summaryData;
  if (siteVisits.length > 0) {
    summaryData = [
      ['Base Plan Drawing Fee:', formatPdfCurrency(totalPlanFee)],
      [`Site Visits Charges (${siteVisits.length} visits):`, formatPdfCurrency(totalVisitsAmount)],
      ['Gross Total Billable Amount:', formatPdfCurrency(totalBillableAmount)],
      ['Total Amount Received:', formatPdfCurrency(totalPaid)],
      ['Net Remaining Balance Due:', formatPdfCurrency(pendingBalance)],
    ];
  } else {
    summaryData = [
      ['Total Agreed Plan Fee:', formatPdfCurrency(totalPlanFee)],
      ['Total Amount Received:', formatPdfCurrency(totalPaid)],
      ['Net Remaining Balance:', formatPdfCurrency(pendingBalance)],
    ];
  }

  const labelColWidth = siteVisits.length > 0 ? 60 : 52;
  const valColWidth = siteVisits.length > 0 ? 34 : 32;

  autoTable(doc, {
    startY: summaryStartY,
    body: summaryData,
    theme: 'grid',
    styles: {
      fontSize: 8,
      cellPadding: 2,
      lineColor: '#E2E8F0',
      lineWidth: 0.2,
    },
    columnStyles: {
      0: { fontStyle: 'bold', textColor: '#475569', halign: 'right', cellWidth: labelColWidth, fillColor: '#F8FAFC' },
      1: { fontStyle: 'bold', textColor: '#0F172A', halign: 'right', cellWidth: valColWidth },
    },
    margin: { left: summaryBoxX, right: margin, top: 16, bottom: 16 },
    tableWidth: summaryBoxWidth,
    didParseCell: function (data) {
      if (siteVisits.length > 0) {
        // Gross Total row
        if (data.row.index === 2) {
          data.cell.styles.fillColor = '#F1F5F9';
          data.cell.styles.textColor = '#0F172A';
          data.cell.styles.fontStyle = 'bold';
        }
        // Total Paid row
        if (data.row.index === 3 && data.column.index === 1) {
          data.cell.styles.textColor = '#059669'; // Green
        }
        // Net Balance row
        if (data.row.index === 4) {
          data.cell.styles.fillColor = pendingBalance > 0 ? '#FEF3C7' : '#D1FAE5';
          data.cell.styles.textColor = pendingBalance > 0 ? '#B45309' : '#059669';
          data.cell.styles.fontStyle = 'bold';
        }
      } else {
        // Highlight Total Paid row
        if (data.row.index === 1 && data.column.index === 1) {
          data.cell.styles.textColor = '#059669'; // Green
        }
        // Highlight Pending Balance row
        if (data.row.index === 2) {
          data.cell.styles.fillColor = pendingBalance > 0 ? '#FEF3C7' : '#D1FAE5';
          data.cell.styles.textColor = pendingBalance > 0 ? '#B45309' : '#059669';
          data.cell.styles.fontStyle = 'bold';
        }
      }
    },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES CHECKLIST TABLE
  // ─────────────────────────────────────────────────────────────────────────
  const plansSectionY = doc.lastAutoTable.finalY + 4.5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(15, 23, 42);
  const scopeTitle = rawPlans.length === 21
    ? `${nextSectionNum}. SCOPE OF 21 ENGINEERING DRAWINGS & DELIVERABLES`
    : `${nextSectionNum}. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES (${rawPlans.length} DELIVERABLES)`;
  doc.text(scopeTitle, margin, plansSectionY);

  const planHeaders = ['#', 'Engineering Plan / Drawing Deliverable', 'Discipline', 'Status / Release'];

  // Sort drawings: Completed (Released) drawings always placed on top
  const sortedPlansForPdf = [...rawPlans].sort((a, b) => {
    const aDone = a.status === 'completed' ? 1 : 0;
    const bDone = b.status === 'completed' ? 1 : 0;
    if (aDone !== bDone) return bDone - aDone;
    const aNum = parseInt(a.num || a.name?.match(/^(\d+)/)?.[1] || '999', 10);
    const bNum = parseInt(b.num || b.name?.match(/^(\d+)/)?.[1] || '999', 10);
    if (aNum !== bNum) return aNum - bNum;
    return (a.name || '').localeCompare(b.name || '');
  });

  const planRows = sortedPlansForPdf.map((p, idx) => {
    const numDisplay = p.num || String(idx + 1).padStart(2, '0');
    const cleanName = (p.name || '').replace(/^\d+[\s._-]+/, '');
    const isCompleted = p.status === 'completed';
    const statusText = isCompleted ? 'COMPLETED (RELEASED)' : p.status === 'in_progress' ? 'IN PROGRESS' : 'NOT STARTED';
    return [
      numDisplay,
      cleanPdfText(`${numDisplay}-${cleanName}`),
      cleanPdfText(p.category || 'Engineering'),
      statusText,
    ];
  });

  // Responsive padding based on plan count (ensures <= 10 plans comfortably stay on 1 page)
  const isCompactScope = rawPlans.length > 8;
  const scopeCellPadding = isCompactScope ? 1.35 : 1.8;
  const scopeFontSize = isCompactScope ? 6.9 : 7.3;

  autoTable(doc, {
    startY: plansSectionY + 2.5,
    head: [planHeaders],
    body: planRows,
    theme: 'grid',
    headStyles: {
      fillColor: '#1E293B', // Dark executive slate for scope table
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 7.2,
      cellPadding: isCompactScope ? 1.5 : 1.8,
    },
    styles: {
      fontSize: scopeFontSize,
      cellPadding: scopeCellPadding,
      textColor: '#1E293B',
      lineColor: '#E2E8F0',
      lineWidth: 0.2,
    },
    columnStyles: {
      0: { cellWidth: 10, halign: 'center', fontStyle: 'bold', textColor: themeHex },
      1: { cellWidth: 96, fontStyle: 'bold' },
      2: { cellWidth: 38, textColor: '#64748B' },
      3: { cellWidth: 38, halign: 'center', fontStyle: 'bold' },
    },
    alternateRowStyles: {
      fillColor: '#F8FAFC',
    },
    didParseCell: function (data) {
      if (data.column.index === 3 && data.section === 'body') {
        const val = data.cell.raw;
        if (typeof val === 'string' && val.includes('COMPLETED')) {
          data.cell.styles.textColor = '#059669'; // Green
        } else if (typeof val === 'string' && val.includes('IN PROGRESS')) {
          data.cell.styles.textColor = '#2563EB'; // Blue
        } else {
          data.cell.styles.textColor = '#64748B'; // Slate
        }
      }
    },
    margin: { left: margin, right: margin, top: 16, bottom: 16 },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. CLEAN FOOTER & MULTI-PAGE NUMBERING (NO WATERMARK)
  // ─────────────────────────────────────────────────────────────────────────
  const pageCount = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);

    // Top Header Mini-strip on continuation pages (Page 2+) placed below 44mm letterhead space
    if (i > 1) {
      doc.setFontSize(7.5);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(51, 65, 85);
      doc.text(`Client: ${ownerName.toUpperCase()}`, margin, 46.5);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
      doc.setTextColor(100, 116, 139);
      doc.text(`Plan Ref: #${planNumber} | Site Visits & Billing Statement`, pageWidth - margin, 46.5, { align: 'right' });
    }

    // Bottom footer line
    doc.setDrawColor(226, 232, 240);
    doc.setLineWidth(0.3);
    doc.line(margin, pageHeight - 9, pageWidth - margin, pageHeight - 9);

    doc.setFontSize(6.8);
    doc.setTextColor(148, 163, 184); // slate-400
    doc.setFont('helvetica', 'normal');
    doc.text(
      `${companyName} | Architecture, Planner, Consultant, Interior Designer | Thank you for your business!`,
      margin,
      pageHeight - 5
    );
    doc.text(`Page ${i} of ${pageCount}`, pageWidth - margin, pageHeight - 5, { align: 'right' });
  }

  // Download PDF file
  const cleanOwnerFileName = ownerName.replace(/[^A-Za-z0-9_-]/g, '_');
  const cleanCoFileName = companyName.replace(/[^A-Za-z0-9_-]/g, '_');
  const safeFilename = `${cleanCoFileName}_Bill_${cleanOwnerFileName}_${planNumber}.pdf`;

  if (saveImmediately) {
    doc.save(safeFilename);
  }

  return doc;
}
