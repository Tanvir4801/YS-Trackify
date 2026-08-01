import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { DEFAULT_BRANDING } from '../context/BrandingContext';
import { formatCurrency } from './utils';

const sanitizePdfText = (val) => {
  if (typeof val === 'string') return val.replace(/₹/g, 'Rs. ');
  return val;
};

export async function generatePDF({
  title,
  subtitle,
  filename,
  columns,
  rows,
  totals,
  branding = DEFAULT_BRANDING,
}) {
  const doc = new jsPDF();
  
  const sanitizedRows = rows.map(r => r.map(c => sanitizePdfText(c)));
  const sanitizedTotals = totals ? Object.fromEntries(Object.entries(totals).map(([k, v]) => [k, sanitizePdfText(v)])) : null;
  
  // Header section
  const themeColor = branding.themeColor || '#F5A623';
  doc.setFillColor(themeColor);
  doc.rect(0, 0, 210, 40, 'F');
  
  doc.setTextColor('#FFFFFF');
  doc.setFontSize(22);
  doc.setFont('helvetica', 'bold');
  
  let textX = 14;

  // Render logo if available
  if (branding.logoUrl) {
    try {
      const img = new Image();
      img.crossOrigin = "Anonymous";
      img.src = branding.logoUrl;
      await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
      });
      
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const dataUrl = canvas.toDataURL('image/png');
      
      // Fit inside a max 26x26 box
      const maxW = 26;
      const maxH = 26;
      let w = img.width;
      let h = img.height;
      
      if (w > maxW || h > maxH) {
        const ratio = Math.min(maxW / w, maxH / h);
        w = w * ratio;
        h = h * ratio;
      }
      
      // Center vertically within the 40 unit header
      const yPos = 20 - (h / 2);
      doc.addImage(dataUrl, 'PNG', 14, yPos, w, h);
      
      textX = 14 + w + 6; // shift text right of logo
    } catch (err) {
      console.warn("Failed to load logo for PDF", err);
    }
  }

  doc.text(branding.companyName || 'Trackify', textX, 20);
  
  doc.setFontSize(14);
  doc.setFont('helvetica', 'normal');
  doc.text(title, textX, 30);
  
  if (subtitle) {
    doc.setFontSize(10);
    doc.text(subtitle, textX, 36);
  }
  
  // Right side branding details
  let rightTextY = 16;
  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor('#FFFFFF');
  const rightX = doc.internal.pageSize.width - 14;
  
  const rightLines = [];
  if (branding.address) rightLines.push(branding.address);
  if (branding.email) rightLines.push(`Email: ${branding.email}`);
  if (branding.phone) rightLines.push(`Phone: ${branding.phone}`);
  if (branding.gstNumber) rightLines.push(`GST: ${branding.gstNumber}`);
  
  rightLines.forEach(line => {
    doc.text(line, rightX, rightTextY, { align: 'right' });
    rightTextY += 5;
  });

  
  doc.setTextColor('#000000');
  
  let startY = 45;
  
  autoTable(doc, {
    startY,
    head: [columns],
    body: sanitizedRows,
    theme: 'grid',
    headStyles: { fillColor: themeColor, textColor: '#FFFFFF', fontStyle: 'bold' },
    styles: { fontSize: 9, cellPadding: 3 },
    alternateRowStyles: { fillColor: '#F9FAFB' },
  });
  
  if (sanitizedTotals) {
    const finalY = doc.lastAutoTable.finalY + 10;
    const totalsData = Object.entries(sanitizedTotals).map(([key, value]) => [key, value]);
    
    autoTable(doc, {
      startY: finalY,
      body: totalsData,
      theme: 'grid',
      styles: { 
        fontSize: 9,
        cellPadding: 3,
      },
      columnStyles: {
        0: { fontStyle: 'bold', textColor: '#4B5563', halign: 'right', fillColor: '#F9FAFB' },
        1: { fontStyle: 'bold', textColor: '#111827', halign: 'right', cellWidth: 40 }
      },
      margin: { left: doc.internal.pageSize.width - 100 - 14 }, // Right align table (width 100, right margin 14)
      tableWidth: 100,
      didParseCell: function (data) {
        // Highlight the last row (Grand Total)
        if (data.row.index === totalsData.length - 1) {
          data.cell.styles.fillColor = themeColor;
          data.cell.styles.textColor = '#FFFFFF';
        }
      }
    });
  }
  
  // Footer & Watermark
  const pageCount = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    
    // Watermark
    doc.setFontSize(40);
    doc.setTextColor(240, 240, 240); // Very light gray for watermark
    doc.text(branding.companyName || 'Trackify', doc.internal.pageSize.width / 2, doc.internal.pageSize.height / 2, {
      align: 'center',
      angle: 45
    });

    // Footer text
    doc.setFontSize(8);
    doc.setTextColor('#9CA3AF');
    const footerY = doc.internal.pageSize.height - 10;
    doc.text(branding.companyName || 'Trackify', 14, footerY);
    doc.text(`Page ${i} of ${pageCount}`, doc.internal.pageSize.width - 25, footerY);
  }
  
  doc.save(filename || 'report.pdf');
}
