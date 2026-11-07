export interface ProblemCard {
  id: string;
  title: string;
  reality: {
    description: string;
  };
  fix: {
    description: string;
  };
}

export const problems: ProblemCard[] = [
  {
    id: 'paper-trap',
    title: 'The Paper Register Trap',
    reality: {
      description:
        'Paper muster rolls get torn, soaked, lost, or falsified. Disputes erupt weekly over who was present and for how many days.',
    },
    fix: {
      description:
        'Tamper-proof digital attendance with exact timestamps and supervisor attribution. Every record is immutable and audit-ready.',
    },
  },
  {
    id: 'advance-leakage',
    title: 'The Advance Payout Leakage',
    reality: {
      description:
        'Cash advances written on scraps of paper cause disputes. Workers forget amounts, contractors lose track, money leaks silently.',
    },
    fix: {
      description:
        'Centralized digital advance ledger that auto-offsets against wages. Every rupee is tracked, every deduction is transparent.',
    },
  },
  {
    id: 'multisite-blackhole',
    title: 'The Multi-Site Black Hole',
    reality: {
      description:
        'Worker shortages and budget overruns are discovered weeks late. No real-time visibility across sites leads to costly surprises.',
    },
    fix: {
      description:
        'Live headcount per site, real-time cost burn tracking, and instant PDF/Excel muster exports. Know everything, everywhere, instantly.',
    },
  },
];

