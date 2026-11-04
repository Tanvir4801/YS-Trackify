import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { DEFAULT_BRANDING } from '../../context/BrandingContext';
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
 * Helper to convert image URL to base64 DataURL via canvas with timeout protection
 */
async function loadLogoDataUrl(url) {
  if (!url) return null;
  try {
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.src = url;
    await new Promise((resolve, reject) => {
      img.onload = resolve;
      img.onerror = reject;
      // 2.5 second timeout to never freeze PDF export
      setTimeout(() => reject(new Error('Logo image load timed out')), 2500);
    });

    const canvas = document.createElement('canvas');
    canvas.width = img.naturalWidth || img.width;
    canvas.height = img.naturalHeight || img.height;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0);
    return {
      dataUrl: canvas.toDataURL('image/png'),
      width: canvas.width,
      height: canvas.height,
    };
  } catch (err) {
    console.warn('Failed to load branding logo for PDF export:', err);
    return null;
  }
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

  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4',
  });

  const pageWidth = doc.internal.pageSize.getWidth(); // 210mm
  const pageHeight = doc.internal.pageSize.getHeight(); // 297mm
  const margin = 14;

  const themeHex = branding?.themeColor || '#F5A623';
  const rgbTheme = hexToRgb(themeHex);

  // Fallback to "YS Construction" if default "Trackify" or blank
  let rawCompanyName = branding?.companyName || '';
  if (!rawCompanyName || rawCompanyName.toLowerCase() === 'trackify') {
    rawCompanyName = 'YS Construction';
  }
  const companyName = rawCompanyName.replace(/_/g, ' ').trim();
  const tagline = branding?.tagline || 'Architecture & Structural Engineering Consultancy';
  const companyAddress = branding?.address || 'Anaval, Gujarat, India';
  const companyPhone = branding?.phone || '+91 7621984915';
  const companyEmail = branding?.email || 'ysconstruction@gmail.com';
  const gstNumber = branding?.gstNumber || '';

  const ownerName = owner.ownerName || 'Client';
  const planNumber = owner.planNumber || 'PLN-2026-001';
  const serialNumber3D = owner.serialNumber3D || '-';
  const billInvoiceNo = `INV-${planNumber.replace(/^PLN-/i, '')}`;
  const totalPlanFee = Number(owner.houseAmount) || 0;
  const totalPaid = Number(owner.totalPaid) || 0;
  const pendingBalance = Math.max(0, totalPlanFee - totalPaid);

  const payments = Array.isArray(owner.payments) ? owner.payments : [];

  // Use owner's plansList if populated; otherwise fallback to the exact 21 default engineering plans
  const rawPlans = Array.isArray(owner.plansList) && owner.plansList.length > 0 ? owner.plansList : DEFAULT_MASTER_PLANS;

  // Determine payment status badge
  let paymentBadgeText = 'PENDING';
  let badgeBgColor = [220, 38, 38]; // Red
  if (totalPaid >= totalPlanFee && totalPlanFee > 0) {
    paymentBadgeText = 'PAID IN FULL';
    badgeBgColor = [16, 185, 129]; // Emerald Green
  } else if (totalPaid >= totalPlanFee * 0.5 && totalPlanFee > 0) {
    paymentBadgeText = '50%+ ADVANCE CLEARED';
    badgeBgColor = [245, 166, 35]; // Gold/Amber
  } else if (totalPaid > 0) {
    paymentBadgeText = 'ADVANCE RECEIVED';
    badgeBgColor = [14, 165, 233]; // Cyan/Sky
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. TOP HEADER BAND (Branded with custom theme color & logo)
  // ─────────────────────────────────────────────────────────────────────────
  doc.setFillColor(...rgbTheme);
  doc.rect(0, 0, pageWidth, 38, 'F');

  // Load Logo if available
  let textStartX = margin;
  const logoInfo = await loadLogoDataUrl(branding?.logoUrl);

  if (logoInfo) {
    try {
      const maxBox = 24;
      const ratio = Math.min(maxBox / logoInfo.width, maxBox / logoInfo.height);
      const renderW = logoInfo.width * ratio;
      const renderH = logoInfo.height * ratio;
      const renderY = 19 - renderH / 2;

      // Clean white rounded backing for logo
      doc.setFillColor(255, 255, 255);
      doc.roundedRect(margin, renderY - 1, renderW + 2, renderH + 2, 2, 2, 'F');
      doc.addImage(logoInfo.dataUrl, 'PNG', margin + 1, renderY, renderW, renderH);

      textStartX = margin + renderW + 5;
    } catch (e) {
      console.warn('Logo draw fallback:', e);
    }
  } else {
    // Stylized Monogram Badge if no image uploaded
    doc.setFillColor(255, 255, 255);
    doc.roundedRect(margin, 7, 24, 24, 3, 3, 'F');
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(13);
    doc.setTextColor(...rgbTheme);
    const monogram = companyName
      .split(' ')
      .map((w) => w[0])
      .slice(0, 2)
      .join('')
      .toUpperCase() || 'YS';
    doc.text(monogram, margin + 6, 22);

    textStartX = margin + 28;
  }

  // Company Name
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(17);
  doc.setTextColor(255, 255, 255);
  doc.text(companyName.toUpperCase(), textStartX, 16.5);

  // Subtitle / Tagline
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(255, 255, 255);
  doc.text(tagline, textStartX, 22.5);
  doc.text('House Planning • 2D Working • 3D Elevation • Structural Design & Sanctions', textStartX, 27.5);

  // Right Header: Invoice Title & Meta Badge
  const rightX = pageWidth - margin;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(13);
  doc.setTextColor(255, 255, 255);
  doc.text('PLANNING INVOICE / BILL', rightX, 15, { align: 'right' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.text(`Bill No: ${billInvoiceNo}`, rightX, 21, { align: 'right' });
  doc.text(`Date: ${formatDate(new Date())}`, rightX, 26, { align: 'right' });

  // Status Pill
  doc.setFillColor(...badgeBgColor);
  doc.roundedRect(rightX - 44, 29, 44, 6, 2, 2, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.setTextColor(255, 255, 255);
  doc.text(paymentBadgeText, rightX - 22, 33.3, { align: 'center' });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. CONTACT DETAILS & CLIENT INFORMATION GRID
  // ─────────────────────────────────────────────────────────────────────────
  const infoTopY = 44;
  const colWidth = (pageWidth - margin * 2 - 6) / 2;
  const infoBoxHeight = 32;

  // Left Box: Consultancy Info
  doc.setFillColor(249, 250, 251);
  doc.setDrawColor(229, 231, 235);
  doc.roundedRect(margin, infoTopY, colWidth, infoBoxHeight, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(107, 114, 128);
  doc.text('ISSUED BY (PLANNING CONSULTANT):', margin + 4, infoTopY + 5.5);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.setTextColor(17, 24, 39);
  doc.text(companyName, margin + 4, infoTopY + 11.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(75, 85, 99);
  doc.text(`Office: ${companyAddress}`, margin + 4, infoTopY + 16.5);
  doc.text(`Phone: ${companyPhone}  •  Email: ${companyEmail}`, margin + 4, infoTopY + 21.5);
  if (gstNumber) {
    doc.text(`GST / Registration: ${gstNumber}`, margin + 4, infoTopY + 26.5);
  } else {
    doc.text(`Supervising Engineer: ${owner.engineerName || 'Er. YS_Construction'}`, margin + 4, infoTopY + 26.5);
  }

  // Right Box: Billed To (Client / Owner)
  const clientBoxX = margin + colWidth + 6;
  doc.setFillColor(249, 250, 251);
  doc.setDrawColor(229, 231, 235);
  doc.roundedRect(clientBoxX, infoTopY, colWidth, infoBoxHeight, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(107, 114, 128);
  doc.text('BILLED TO (HOUSE OWNER / CLIENT):', clientBoxX + 4, infoTopY + 5.5);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.setTextColor(17, 24, 39);
  doc.text(ownerName.toUpperCase(), clientBoxX + 4, infoTopY + 11.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(75, 85, 99);
  doc.text(`Phone: ${owner.ownerPhone || 'N/A'}`, clientBoxX + 4, infoTopY + 16.5);
  doc.text(`Site Location: ${owner.city || owner.town || owner.ownerAddress || 'Anaval'}`, clientBoxX + 4, infoTopY + 21.5);
  doc.text(`Plan Serial No: ${planNumber}  •  3D Model Ref: ${serialNumber3D}`, clientBoxX + 4, infoTopY + 26.5);

  // ─────────────────────────────────────────────────────────────────────────
  // 3. PROJECT & ARCHITECTURE SPECIFICATIONS BAR
  // ─────────────────────────────────────────────────────────────────────────
  const specY = 79;
  doc.setFillColor(243, 244, 246);
  doc.setDrawColor(229, 231, 235);
  doc.roundedRect(margin, specY, pageWidth - margin * 2, 11, 2, 2, 'FD');

  const specColWidth = (pageWidth - margin * 2) / 4;
  doc.setFontSize(7.5);

  // Spec 1: Total Built-up Area
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(107, 114, 128);
  doc.text('TOTAL BUILT-UP AREA:', margin + 4, specY + 4.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(17, 24, 39);
  doc.text(`${Number(owner.totalSqFt || 0).toLocaleString('en-IN')} sq.ft`, margin + 4, specY + 8.5);

  // Spec 2: Rate per sq.ft
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(107, 114, 128);
  doc.text('PLANNING RATE:', margin + specColWidth + 4, specY + 4.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(17, 24, 39);
  const rateDisplay = owner.ratePerSqFt ? `Rs. ${owner.ratePerSqFt}/sq.ft` : totalPlanFee && owner.totalSqFt ? `Rs. ${Math.round(totalPlanFee / owner.totalSqFt)}/sq.ft` : 'Fixed Fee';
  doc.text(rateDisplay, margin + specColWidth + 4, specY + 8.5);

  // Spec 3: Structural Specs
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(107, 114, 128);
  doc.text('FLOORS & ORIENTATION:', margin + specColWidth * 2 + 4, specY + 4.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(17, 24, 39);
  doc.text(`${owner.floors || 'G+1'} • ${owner.bhk || '3 BHK'} • ${owner.facing || 'East'}`, margin + specColWidth * 2 + 4, specY + 8.5);

  // Spec 4: Engineer In-Charge
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(107, 114, 128);
  doc.text('PROJECT ENGINEER:', margin + specColWidth * 3 + 4, specY + 4.5);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...rgbTheme);
  doc.text(owner.engineerName || 'Er. YS_Construction', margin + specColWidth * 3 + 4, specY + 8.5);

  // ─────────────────────────────────────────────────────────────────────────
  // 4. PAYMENTS & ADVANCE INSTALLMENTS LEDGER TABLE
  // ─────────────────────────────────────────────────────────────────────────
  const paymentSectionY = 94;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9.5);
  doc.setTextColor(17, 24, 39);
  doc.text('1. PAYMENT INSTALLMENTS & ADVANCE LEDGER', margin, paymentSectionY);

  const paymentHeaders = ['Installment / Milestone Description', 'Date', 'Mode', 'Reference / UTR', 'Amount Received'];

  let paymentRows = [];
  if (payments.length > 0) {
    paymentRows = payments.map((p, idx) => [
      `${idx + 1}. ${p.installmentName || p.type || 'Part Payment'}`,
      p.date ? formatDate(p.date) : '-',
      p.mode || 'UPI',
      p.referenceNo || p.notes || '-',
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
      cellPadding: 2.5,
    },
    styles: {
      fontSize: 8,
      cellPadding: 2.2,
      textColor: '#1F2937',
    },
    columnStyles: {
      0: { cellWidth: 70, fontStyle: 'bold' },
      1: { cellWidth: 26, halign: 'center' },
      2: { cellWidth: 22, halign: 'center' },
      3: { cellWidth: 36, textColor: '#4B5563' },
      4: { cellWidth: 28, halign: 'right', fontStyle: 'bold' },
    },
    alternateRowStyles: {
      fillColor: '#F9FAFB',
    },
    margin: { left: margin, right: margin, top: 16, bottom: 16 },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. FINANCIAL BILLING SUMMARY BOX
  // ─────────────────────────────────────────────────────────────────────────
  const summaryStartY = doc.lastAutoTable.finalY + 3.5;
  const summaryBoxWidth = 84;
  const summaryBoxX = pageWidth - margin - summaryBoxWidth;

  const summaryData = [
    ['Total Agreed Plan Fee:', formatPdfCurrency(totalPlanFee)],
    ['Total Amount Received to Date:', formatPdfCurrency(totalPaid)],
    ['Net Remaining Balance Pending:', formatPdfCurrency(pendingBalance)],
  ];

  autoTable(doc, {
    startY: summaryStartY,
    body: summaryData,
    theme: 'grid',
    styles: {
      fontSize: 8.5,
      cellPadding: 2.2,
    },
    columnStyles: {
      0: { fontStyle: 'bold', textColor: '#4B5563', halign: 'right', cellWidth: 52, fillColor: '#F9FAFB' },
      1: { fontStyle: 'bold', textColor: '#111827', halign: 'right', cellWidth: 32 },
    },
    margin: { left: summaryBoxX, right: margin, top: 16, bottom: 16 },
    tableWidth: summaryBoxWidth,
    didParseCell: function (data) {
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
    },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. SCOPE OF 21 ENGINEERING DRAWINGS CHECKLIST TABLE
  // ─────────────────────────────────────────────────────────────────────────
  const plansSectionY = doc.lastAutoTable.finalY + 5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9.5);
  doc.setTextColor(17, 24, 39);
  doc.text('2. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES (21 PLANS)', margin, plansSectionY);

  const planHeaders = ['#', 'Engineering Plan / Drawing Deliverable', 'Discipline', 'Status / Release'];

  const planRows = rawPlans.map((p, idx) => {
    const numDisplay = p.num || String(idx + 1).padStart(2, '0');
    const cleanName = (p.name || '').replace(/^\d+[\s._-]+/, '');
    const isCompleted = p.status === 'completed';
    const statusText = isCompleted ? 'COMPLETED (RELEASED)' : p.status === 'in_progress' ? 'IN PROGRESS' : 'NOT STARTED';
    return [
      numDisplay,
      `${numDisplay}-${cleanName}`,
      p.category || 'Engineering',
      statusText,
    ];
  });

  autoTable(doc, {
    startY: plansSectionY + 2.5,
    head: [planHeaders],
    body: planRows,
    theme: 'grid',
    headStyles: {
      fillColor: '#374151', // Dark slate for drawings scope
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 7.5,
      cellPadding: 2,
    },
    styles: {
      fontSize: 7.5,
      cellPadding: 1.8,
      textColor: '#1F2937',
    },
    columnStyles: {
      0: { cellWidth: 10, halign: 'center', fontStyle: 'bold', textColor: themeHex },
      1: { cellWidth: 96, fontStyle: 'bold' },
      2: { cellWidth: 38, textColor: '#4B5563' },
      3: { cellWidth: 38, halign: 'center', fontStyle: 'bold' },
    },
    alternateRowStyles: {
      fillColor: '#F9FAFB',
    },
    didParseCell: function (data) {
      if (data.column.index === 3 && data.section === 'body') {
        const val = data.cell.raw;
        if (typeof val === 'string' && val.includes('COMPLETED')) {
          data.cell.styles.textColor = '#059669';
        } else if (typeof val === 'string' && val.includes('IN PROGRESS')) {
          data.cell.styles.textColor = '#2563EB';
        } else {
          data.cell.styles.textColor = '#6B7280';
        }
      }
    },
    margin: { left: margin, right: margin, top: 16, bottom: 16 },
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. TERMS, CONDITIONS & AUTHORIZED SIGNATURE BLOCKS
  // ─────────────────────────────────────────────────────────────────────────
  let signY = doc.lastAutoTable.finalY + 8;

  // Check if signature section fits on current page, otherwise add a page
  if (signY > pageHeight - 38) {
    doc.addPage();
    signY = 25;
  }

  // Terms Box (Left side)
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(17, 24, 39);
  doc.text('TERMS & CONDITIONS:', margin, signY);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.5);
  doc.setTextColor(107, 114, 128);
  doc.text('1. All structural drawings are designed as per Indian Standard (IS 456 / NBC) soil & loading standards.', margin, signY + 4);
  doc.text('2. Passing plans and loan estimates are certified for municipal sanction and banking valuation.', margin, signY + 7.5);
  doc.text('3. Any revision beyond standard architectural draft will be charged as per agreed schedule.', margin, signY + 11);
  doc.text('4. Complete drawing set and soft copy release are subject to full plan fee settlement.', margin, signY + 14.5);

  // Signatures
  const sigLineY = signY + 24;

  // Client Signature (Left)
  doc.setDrawColor(156, 163, 175);
  doc.line(margin, sigLineY, margin + 45, sigLineY);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(75, 85, 99);
  doc.text('Client Acceptance Signature', margin, sigLineY + 4);
  doc.text(`(${ownerName})`, margin, sigLineY + 7.5);

  // Consultant Authorized Signature (Right)
  const authSigX = pageWidth - margin - 55;
  doc.line(authSigX, sigLineY, authSigX + 55, sigLineY);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(...rgbTheme);
  doc.text(`For ${companyName}`, authSigX, sigLineY + 4);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(75, 85, 99);
  doc.text('Authorized Signatory & Seal', authSigX, sigLineY + 7.5);

  // ─────────────────────────────────────────────────────────────────────────
  // 8. FOOTER & MULTI-PAGE NUMBERING
  // ─────────────────────────────────────────────────────────────────────────
  const pageCount = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);

    // Subtle background watermark on page 1
    if (i === 1) {
      doc.setFontSize(36);
      doc.setTextColor(245, 245, 245);
      doc.setFont('helvetica', 'bold');
      doc.text(companyName.toUpperCase(), pageWidth / 2, pageHeight / 2, {
        align: 'center',
        angle: 35,
      });
    }

    // Top Header Mini-strip on continuation pages (Page 2+)
    if (i > 1) {
      doc.setFillColor(...rgbTheme);
      doc.rect(0, 0, pageWidth, 6, 'F');
      doc.setFontSize(7.5);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(255, 255, 255);
      doc.text(`${companyName.toUpperCase()} — PLANNING INVOICE & DELIVERABLES (Ref: ${billInvoiceNo})`, margin, 4.2);
      doc.text(`Client: ${ownerName}`, pageWidth - margin, 4.2, { align: 'right' });
    }

    // Bottom footer line
    doc.setDrawColor(229, 231, 235);
    doc.line(margin, pageHeight - 10, pageWidth - margin, pageHeight - 10);

    doc.setFontSize(7);
    doc.setTextColor(156, 163, 175);
    doc.setFont('helvetica', 'normal');
    doc.text(
      `${companyName} • Architectural & Structural Engineering • Thank you for your business!`,
      margin,
      pageHeight - 6
    );
    doc.text(`Page ${i} of ${pageCount}`, pageWidth - margin, pageHeight - 6, { align: 'right' });
  }

  // Download PDF file
  const cleanOwnerFileName = ownerName.replace(/[^A-Za-z0-9_-]/g, '_');
  const safeFilename = `YS_Construction_Bill_${cleanOwnerFileName}_${planNumber}.pdf`;

  if (saveImmediately) {
    doc.save(safeFilename);
  }

  return doc;
}
