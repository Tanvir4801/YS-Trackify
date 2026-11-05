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
  doc.text('YS Construction', centerX, y + 21.2, { align: 'center' });
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
    rawCompanyName = 'YS Construction';
  }
  const companyName = rawCompanyName.replace(/_/g, ' ').trim();
  const tagline = effectiveBranding?.tagline || 'Architecture, Planner, Consultant, Interior Designer';
  const companyAddress = effectiveBranding?.address || 'Gokuldham Complex, Opp. Doodh Dairy, ANGALDHARA, Ta. Mahuva, Dist. Surat';
  const companyPhone = effectiveBranding?.phone || '+91 80003 40720, +91 99044 45077';
  const companyEmail = effectiveBranding?.email || 'ysconstruction24@gmail.com';
  const gstNumber = effectiveBranding?.gstNumber || '';

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
  let badgeTextColor = [255, 255, 255];
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
  // 1. TOP EXECUTIVE PARTNER RIBBON (Directly from Business Card)
  // ─────────────────────────────────────────────────────────────────────────
  // Deep dark executive slate strip (y = 0 to 7mm)
  doc.setFillColor(15, 23, 42); // slate-900
  doc.rect(0, 0, pageWidth, 7, 'F');

  // Subtle bottom gold accent line (0.4mm)
  doc.setFillColor(245, 166, 35);
  doc.rect(0, 6.6, pageWidth, 0.4, 'F');

  // Left Partner: Yogeshwar S. Patel
  const p1Name = 'YOGESHWAR S. PATEL';
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(245, 166, 35); // Crisp Bright Gold
  doc.text(p1Name, margin, 4.8);
  const p1Width = doc.getTextWidth(p1Name);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(255, 255, 255); // Crisp White
  doc.text('•   Mo. 80003 40720', margin + p1Width + 3.5, 4.8);

  // Right Partner: Shirish D. Patel
  const rightPartnerX = pageWidth - margin;
  const p2PhoneText = '•   Mo. 99044 45077';
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(255, 255, 255); // Crisp White
  const phoneW = doc.getTextWidth(p2PhoneText);
  doc.text(p2PhoneText, rightPartnerX, 4.8, { align: 'right' });

  const p2Name = 'SHIRISH D. PATEL';
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(245, 166, 35); // Crisp Bright Gold
  doc.text(p2Name, rightPartnerX - phoneW - 3.5, 4.8, { align: 'right' });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. MAIN BRAND HEADER BLOCK (Modern Clean Luxury Layout)
  // ─────────────────────────────────────────────────────────────────────────
  // White header canvas (y = 7mm to 39mm)
  doc.setFillColor(255, 255, 255);
  doc.rect(0, 7, pageWidth, 32, 'F');
  doc.setDrawColor(226, 232, 240); // slate-200
  doc.setLineWidth(0.3);
  doc.line(margin, 39, pageWidth - margin, 39);

  // Load logo from branding screen (logoDataUrl or logoUrl)
  const logoInfo = await loadLogoDataUrl(effectiveBranding?.logoUrl, effectiveBranding?.logoDataUrl);
  const logoBoxX = margin;
  const logoBoxY = 10;
  const logoBoxSize = 25;

  if (logoInfo) {
    try {
      const padding = 2;
      const maxW = logoBoxSize - padding * 2;
      const maxH = logoBoxSize - padding * 2;
      const ratio = Math.min(maxW / logoInfo.width, maxH / logoInfo.height);
      const renderW = logoInfo.width * ratio;
      const renderH = logoInfo.height * ratio;
      const renderX = logoBoxX + (logoBoxSize - renderW) / 2;
      const renderY = logoBoxY + (logoBoxSize - renderH) / 2;

      // Rounded container card
      doc.setFillColor(255, 255, 255);
      doc.setDrawColor(226, 232, 240);
      doc.setLineWidth(0.3);
      doc.roundedRect(logoBoxX, logoBoxY, logoBoxSize, logoBoxSize, 2, 2, 'FD');

      let imgFormat = 'PNG';
      if (logoInfo.dataUrl.startsWith('data:image/jpeg') || logoInfo.dataUrl.startsWith('data:image/jpg')) {
        imgFormat = 'JPEG';
      } else if (logoInfo.dataUrl.startsWith('data:image/webp')) {
        imgFormat = 'WEBP';
      }
      doc.addImage(logoInfo.dataUrl, imgFormat, renderX, renderY, renderW, renderH);
    } catch (e) {
      console.warn('Logo draw fallback, rendering vector emblem:', e);
      drawBusinessCardVectorLogo(doc, logoBoxX, logoBoxY, logoBoxSize, logoBoxSize);
    }
  } else {
    // Exact architectural house & curved foundation arc logo from business card
    drawBusinessCardVectorLogo(doc, logoBoxX, logoBoxY, logoBoxSize, logoBoxSize);
  }

  // Company Information: ONLY Title and Tagline (Clean & Executive)
  const brandTextX = margin + logoBoxSize + 6;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  doc.setTextColor(15, 23, 42); // slate-900
  doc.text(companyName.toUpperCase(), brandTextX, 20.5);

  // Tagline / Nature of Business in Warm Amber Gold
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(217, 119, 6); // amber-600 / gold
  doc.text(tagline.toUpperCase(), brandTextX, 26.5);

  // Right Header: Invoice Title & Meta
  const rightX = pageWidth - margin;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(13);
  doc.setTextColor(15, 23, 42);
  doc.text('PLANNING INVOICE / BILL', rightX, 15, { align: 'right' });

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(217, 119, 6);
  doc.text(`Bill Ref: ${billInvoiceNo}`, rightX, 20.5, { align: 'right' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.8);
  doc.setTextColor(100, 116, 139);
  doc.text(`Date: ${formatDate(new Date())}`, rightX, 25.5, { align: 'right' });

  // Status Pill
  doc.setFillColor(...badgeBgColor);
  doc.roundedRect(rightX - 44, 28.5, 44, 5.5, 2, 2, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.setTextColor(...badgeTextColor);
  doc.text(paymentBadgeText, rightX - 22, 32.5, { align: 'center' });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. CONTACT DETAILS & CLIENT INFORMATION CARDS (Auto-Wrapping & Dynamic Height)
  // ─────────────────────────────────────────────────────────────────────────
  const infoTopY = 42.5;
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

  doc.text(`Plan Serial No: ${planNumber}  •  3D Model Ref: ${serialNumber3D}`, clientBoxX + innerPad, curRightY);
  curRightY += 3.8;
  doc.text(`Supervising Engineer: ${owner.engineerName || 'Er. YS_Construction'}`, clientBoxX + innerPad, curRightY);

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
  doc.text(`${Number(owner.totalSqFt || 0).toLocaleString('en-IN')} sq.ft`, margin + 4, specY + 8.2);

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
  doc.text(`${owner.floors || 'G+1'} • ${owner.bhk || '3 BHK'} • ${owner.facing || 'East'}`, margin + specColWidth * 2 + 4, specY + 8.2);

  // Spec 4: Engineer In-Charge
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(100, 116, 139);
  doc.text('PROJECT ENGINEER:', margin + specColWidth * 3 + 4, specY + 4.2);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(217, 119, 6);
  doc.text(owner.engineerName || 'Er. YS_Construction', margin + specColWidth * 3 + 4, specY + 8.2);

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
  // 6. FINANCIAL BILLING SUMMARY BOX
  // ─────────────────────────────────────────────────────────────────────────
  const summaryStartY = doc.lastAutoTable.finalY + 3;
  const summaryBoxWidth = 84;
  const summaryBoxX = pageWidth - margin - summaryBoxWidth;

  const summaryData = [
    ['Total Agreed Plan Fee:', formatPdfCurrency(totalPlanFee)],
    ['Total Advance Received:', formatPdfCurrency(totalPaid)],
    ['Net Remaining Balance:', formatPdfCurrency(pendingBalance)],
  ];

  autoTable(doc, {
    startY: summaryStartY,
    body: summaryData,
    theme: 'grid',
    styles: {
      fontSize: 8.2,
      cellPadding: 2,
      lineColor: '#E2E8F0',
      lineWidth: 0.2,
    },
    columnStyles: {
      0: { fontStyle: 'bold', textColor: '#475569', halign: 'right', cellWidth: 52, fillColor: '#F8FAFC' },
      1: { fontStyle: 'bold', textColor: '#0F172A', halign: 'right', cellWidth: 32 },
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
  // 7. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES CHECKLIST TABLE
  // ─────────────────────────────────────────────────────────────────────────
  const plansSectionY = doc.lastAutoTable.finalY + 4.5;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(15, 23, 42);
  const scopeTitle = rawPlans.length === 21
    ? '2. SCOPE OF 21 ENGINEERING DRAWINGS & DELIVERABLES'
    : `2. SCOPE OF ENGINEERING DRAWINGS & DELIVERABLES (${rawPlans.length} DELIVERABLES)`;
  doc.text(scopeTitle, margin, plansSectionY);

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
  // 8. TERMS, CONDITIONS & AUTHORIZED SIGNATURE / OFFICIAL SEAL BLOCKS
  // ─────────────────────────────────────────────────────────────────────────
  const termsBoxH = 13.5;
  const sigBoxH = 22;
  const neededSignSpace = termsBoxH + sigBoxH + 8; // ~43.5mm total
  const currentFinalY = doc.lastAutoTable.finalY;
  const bottomFooterLimit = pageHeight - 12; // 285mm (above bottom footer line)

  let signY;
  // If content cannot fit on the current page before footer, add page 2
  if (currentFinalY + neededSignSpace > bottomFooterLimit) {
    doc.addPage();
    signY = 16;
  } else {
    // If it fits on the current page (e.g. single-page bill with <= 8-10 plans):
    // Anchor gracefully towards bottom to give a balanced, filled-out appearance
    const minSignY = currentFinalY + 5;
    const bottomAnchoredY = bottomFooterLimit - neededSignSpace - 2;
    // On page 1 with few plans, anchor towards bottom; on continuation page, keep reasonably close
    signY = doc.internal.getNumberOfPages() === 1
      ? Math.max(minSignY, bottomAnchoredY)
      : Math.max(minSignY, Math.min(minSignY + 12, bottomAnchoredY));
  }

  // --- Terms Box (2 Clean Balanced Columns) ---
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(margin, signY, pageWidth - margin * 2, termsBoxH, 1.5, 1.5, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.8);
  doc.setTextColor(15, 23, 42);
  doc.text('TERMS & CONDITIONS:', margin + 3.5, signY + 3.6);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.1);
  doc.setTextColor(100, 116, 139);
  const termsColW = (pageWidth - margin * 2 - 8) / 2;

  // Left terms column
  doc.text('1. Structural drawings designed per IS 456 / NBC loading & soil standards.', margin + 3.5, signY + 7.2);
  doc.text('2. Sanction plans & loan estimates certified for municipal & banking valuation.', margin + 3.5, signY + 10.6);

  // Right terms column
  const termsRightX = margin + termsColW + 6;
  doc.text('3. Any revisions beyond agreed architectural draft will be charged as per schedule.', termsRightX, signY + 7.2);
  doc.text('4. Complete drawing set & CAD soft copies released upon full plan fee settlement.', termsRightX, signY + 10.6);

  // --- Signatures & Official Company Seal Section (3 Balanced Columns) ---
  const sigSectionY = signY + termsBoxH + 4.5;
  const availableWidth = pageWidth - margin * 2;
  const colW = availableWidth / 3;

  // 1. Client Acceptance (Left Column)
  const clientSigX = margin;
  const clientLineW = colW - 8;
  const sigLineY = sigSectionY + 13;

  doc.setDrawColor(156, 163, 175);
  doc.setLineWidth(0.3);
  doc.line(clientSigX, sigLineY, clientSigX + clientLineW, sigLineY);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.8);
  doc.setTextColor(71, 85, 105);
  doc.text('Client Acceptance Signature', clientSigX, sigLineY + 3.8);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.2);
  doc.setTextColor(15, 23, 42);
  doc.text(`Client: ${ownerName}`, clientSigX, sigLineY + 7.2);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.2);
  doc.setTextColor(148, 163, 184);
  doc.text('Date: _______________', clientSigX, sigLineY + 10.5);

  // 2. Official Company Seal & Stamp Box (Center Column)
  const sealW = 54;
  const sealH = 22;
  const sealX = margin + colW + (colW - sealW) / 2;
  const sealY = sigSectionY;

  // Official dashed seal boundary in brand theme gold
  doc.setDrawColor(217, 119, 6);
  doc.setLineWidth(0.4);
  doc.setLineDashPattern([1.5, 1.2], 0);
  doc.roundedRect(sealX, sealY, sealW, sealH, 2, 2, 'D');
  doc.setLineDashPattern([], 0); // reset dash

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(5.8);
  doc.setTextColor(217, 119, 6); // amber-600
  doc.text('OFFICIAL COMPANY SEAL / STAMP', sealX + sealW / 2, sealY + 4.2, { align: 'center' });

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(15, 23, 42); // slate-900
  doc.text('YS CONSTRUCTION', sealX + sealW / 2, sealY + 9.2, { align: 'center' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(5.8);
  doc.setTextColor(71, 85, 105);
  doc.text('Consulting Engineers & Architects', sealX + sealW / 2, sealY + 13.5, { align: 'center' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(5.5);
  doc.setTextColor(148, 163, 184);
  doc.text('ANGALDHARA • DIST. SURAT', sealX + sealW / 2, sealY + 17.5, { align: 'center' });

  // 3. Consultant Authorized Signatory (Right Column)
  const authSigW = colW - 6;
  const authSigX = pageWidth - margin - authSigW;

  doc.setDrawColor(156, 163, 175);
  doc.setLineWidth(0.3);
  doc.line(authSigX, sigLineY, authSigX + authSigW, sigLineY);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(217, 119, 6); // amber/gold
  doc.text(`For ${companyName}`, authSigX, sigLineY + 3.8);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(6.8);
  doc.setTextColor(15, 23, 42);
  doc.text('Authorized Signatory & Consultant', authSigX, sigLineY + 7.2);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(6.2);
  doc.setTextColor(71, 85, 105);
  doc.text('(Yogeshwar S. Patel / Shirish D. Patel)', authSigX, sigLineY + 10.5);

  // ─────────────────────────────────────────────────────────────────────────
  // 9. CLEAN FOOTER & MULTI-PAGE NUMBERING (NO WATERMARK)
  // ─────────────────────────────────────────────────────────────────────────
  const pageCount = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);

    // Top Header Mini-strip on continuation pages (Page 2+)
    if (i > 1) {
      doc.setFillColor(15, 23, 42);
      doc.rect(0, 0, pageWidth, 5.5, 'F');
      doc.setFillColor(...rgbTheme);
      doc.rect(0, 5.2, pageWidth, 0.3, 'F');
      doc.setFontSize(7);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(255, 255, 255);
      doc.text(`${companyName.toUpperCase()} — PLANNING INVOICE & DELIVERABLES (Ref: ${billInvoiceNo})`, margin, 3.8);
      doc.text(`Client: ${ownerName}`, pageWidth - margin, 3.8, { align: 'right' });
    }

    // Bottom footer line
    doc.setDrawColor(226, 232, 240);
    doc.setLineWidth(0.3);
    doc.line(margin, pageHeight - 9, pageWidth - margin, pageHeight - 9);

    doc.setFontSize(6.8);
    doc.setTextColor(148, 163, 184); // slate-400
    doc.setFont('helvetica', 'normal');
    doc.text(
      `${companyName} • Architecture, Planner, Consultant, Interior Designer • Thank you for your business!`,
      margin,
      pageHeight - 5
    );
    doc.text(`Page ${i} of ${pageCount}`, pageWidth - margin, pageHeight - 5, { align: 'right' });
  }

  // Download PDF file
  const cleanOwnerFileName = ownerName.replace(/[^A-Za-z0-9_-]/g, '_');
  const safeFilename = `YS_Construction_Bill_${cleanOwnerFileName}_${planNumber}.pdf`;

  if (saveImmediately) {
    doc.save(safeFilename);
  }

  return doc;
}
