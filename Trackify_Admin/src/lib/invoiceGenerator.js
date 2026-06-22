import jsPDF from 'jspdf';
import 'jspdf-autotable';
import { DEFAULT_BRANDING } from '../context/BrandingContext';

export function generateInvoicePDF({
  invoiceNumber,
  date,
  dueDate,
  billTo,
  items,
  total,
  filename,
  branding = DEFAULT_BRANDING,
}) {
  const doc = new jsPDF();
  
  const themeColor = branding.themeColor || '#F5A623';
  
  // Header
  doc.setFillColor(themeColor);
  doc.rect(0, 0, 210, 30, 'F');
  
  doc.setTextColor('#FFFFFF');
  doc.setFontSize(24);
  doc.setFont('helvetica', 'bold');
  doc.text('INVOICE', 14, 20);
  
  // Company details (right aligned)
  doc.setFontSize(12);
  const companyName = branding.companyName || 'Trackify';
  const textWidth = doc.getStringUnitWidth(companyName) * doc.internal.getFontSize() / doc.internal.scaleFactor;
  doc.text(companyName, 210 - 14 - textWidth, 20);
  
  doc.setTextColor('#000000');
  
  // Invoice details
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`Invoice Number: ${invoiceNumber}`, 14, 45);
  doc.text(`Date: ${date}`, 14, 51);
  if (dueDate) {
    doc.text(`Due Date: ${dueDate}`, 14, 57);
  }
  
  // Bill To
  doc.setFont('helvetica', 'bold');
  doc.text('Bill To:', 14, 70);
  doc.setFont('helvetica', 'normal');
  doc.text(billTo.name, 14, 76);
  if (billTo.address) doc.text(billTo.address, 14, 82);
  if (billTo.phone) doc.text(billTo.phone, 14, 88);
  
  let startY = 100;
  
  const tableRows = items.map(item => [
    item.description,
    item.quantity,
    item.unitPrice,
    item.total
  ]);
  
  doc.autoTable({
    startY,
    head: [['Description', 'Quantity', 'Unit Price', 'Total']],
    body: tableRows,
    theme: 'grid',
    headStyles: { fillColor: themeColor, textColor: '#FFFFFF', fontStyle: 'bold' },
    styles: { fontSize: 10, cellPadding: 4 },
    alternateRowStyles: { fillColor: '#F9FAFB' },
    columnStyles: {
      1: { halign: 'center' },
      2: { halign: 'right' },
      3: { halign: 'right' }
    }
  });
  
  const finalY = doc.lastAutoTable.finalY + 10;
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  const totalText = `Total: ${total}`;
  const totalWidth = doc.getStringUnitWidth(totalText) * doc.internal.getFontSize() / doc.internal.scaleFactor;
  doc.text(totalText, 210 - 14 - totalWidth, finalY);
  
  // Footer
  const footerY = doc.internal.pageSize.height - 15;
  doc.setFontSize(8);
  doc.setTextColor('#9CA3AF');
  doc.setFont('helvetica', 'normal');
  doc.text('Powered by Trackify', 14, footerY);
  
  if (branding.address || branding.email || branding.phone) {
    const contact = [branding.address, branding.email, branding.phone].filter(Boolean).join(' | ');
    const contactWidth = doc.getStringUnitWidth(contact) * doc.internal.getFontSize() / doc.internal.scaleFactor;
    doc.text(contact, 210 - 14 - contactWidth, footerY);
  }
  
  doc.save(filename || `invoice_${invoiceNumber}.pdf`);
}
