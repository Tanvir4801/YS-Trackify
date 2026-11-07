export interface FAQItem {
  question: string;
  answer: string;
}

export const faqItems: FAQItem[] = [
  {
    question: 'What devices does Trackify support?',
    answer:
      'Trackify offers an Android app optimized for low-spec phones commonly used on construction sites, plus a full web admin panel that works on any modern desktop browser — Chrome, Edge, Safari, and Firefox.',
  },
  {
    question: 'Does it work with poor or no internet?',
    answer:
      'Yes. Trackify is built offline-first. Attendance and advance records are securely buffered on the device and auto-sync to the cloud the moment connectivity is restored. Perfect for basements, remote sites, and areas with spotty coverage.',
  },
  {
    question: 'How does QR attendance work?',
    answer:
      'Each worker gets a unique digital or printed QR badge. The supervisor simply scans it with the app camera and attendance is recorded in under a second with the exact timestamp and supervisor attribution.',
  },
  {
    question: 'How are mid-week advances handled in payroll?',
    answer:
      'Every advance is logged in the worker\'s digital ledger the moment it\'s given. When the 1-click payroll engine runs, advances are automatically subtracted from the gross wage — zero manual math, zero disputes.',
  },
  {
    question: 'What is the House Planning & Drawings feature?',
    answer:
      'It tracks all 23 standard engineering drawings (from foundation to 3D elevation), logs site visit records with detailed notes, and generates professional PDF client billing statements with letterhead space and advance tracking.',
  },
  {
    question: 'How can I get started or request a demo?',
    answer:
      'Fill the "Book a Free Demo" form on this page or reach out directly on WhatsApp. We\'ll set up your organization, create your first site, and guide your team through the entire onboarding process.',
  },
];

