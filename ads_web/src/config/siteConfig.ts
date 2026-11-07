export const siteConfig = {
  productName: 'Trackify',
  tagline: 'Every Worker. Every Site. Under Control.',
  heroHeadline: 'Take Control of Your Construction Workforce.',
  heroDescription:
    'Manage workers across multiple sites, record tamper-proof attendance, automate advance deductions, and generate accurate weekly payroll in one connected platform.',
  heroBadge: 'NEW V1.0 · Built Specifically for the Modern Construction Site',
  founder: {
    name: 'Tanvir Patel',
    title: 'Founder & Software Architect',
    education: '4th-Year B.Tech Information Technology Student',
  },
  contact: {
    whatsappNumber: '+917621984915',
    email: 'contact@trackify.live',
    location: 'Surat / Gujarat, India',
  },
  metrics: [
    { label: 'Attendance Speed', value: '< 3s', suffix: '' },
    { label: 'Payroll Math Accuracy', value: '100', suffix: '%' },
    { label: 'Offline Capability', value: '100', suffix: '%' },
    { label: 'Drawings Tracked', value: '23', suffix: ' Plans' },
  ],
  links: {
    adminWebLogin: 'https://ys-trackify.vercel.app',
    adminDemo: 'https://ys-trackify.vercel.app/demo',
    apkDownload: '/downloads/trackify-supervisor.apk',
    whatsappDemo: 'https://wa.me/917621984915?text=Hi%20Trackify%20team%2C%20I%20would%20like%20to%20book%20a%20live%20demo%20for%20my%20construction%20company.',
  },
  seo: {
    title: 'Trackify — Construction Workforce Management Software',
    description:
      'Manage workers, track site attendance, organize wages, and monitor construction workforce operations through one connected platform.',
  },
} as const;

export type SiteConfig = typeof siteConfig;

