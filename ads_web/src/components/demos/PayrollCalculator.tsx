import { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Calculator, ChevronDown } from 'lucide-react';
import { workerRoles, type WorkerRole } from '@/data/demo';
import { formatINR } from '@/utils/formatCurrency';

type PaymentStatus = 'paid' | 'partial' | 'carried';

const statusConfig: Record<PaymentStatus, { label: string; color: string; bg: string }> = {
  paid: { label: 'Paid', color: 'text-trackify-emerald', bg: 'bg-trackify-emerald/20 border-trackify-emerald/40' },
  partial: { label: 'Partially Paid', color: 'text-trackify-amber', bg: 'bg-trackify-amber/20 border-trackify-amber/40' },
  carried: { label: 'Carried Forward', color: 'text-trackify-cyan', bg: 'bg-trackify-cyan/20 border-trackify-cyan/40' },
};

function useAnimatedCount(target: number, duration = 400): number {
  const [current, setCurrent] = useState(target);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    const start = current;
    const diff = target - start;
    if (diff === 0) return;

    const startTime = performance.now();
    const animate = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setCurrent(Math.round(start + diff * eased));
      if (progress < 1) {
        rafRef.current = requestAnimationFrame(animate);
      }
    };

    rafRef.current = requestAnimationFrame(animate);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, duration]);

  return current;
}

export default function PayrollCalculator() {
  const [selectedRole, setSelectedRole] = useState<WorkerRole>(workerRoles[0]);
  const [daysWorked, setDaysWorked] = useState(5);
  const [overtimeBonus, setOvertimeBonus] = useState(0);
  const [advances, setAdvances] = useState(0);
  const [otherDeductions, setOtherDeductions] = useState(0);
  const [paymentStatus, setPaymentStatus] = useState<PaymentStatus>('paid');
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const grossPay = daysWorked * selectedRole.dailyRate;
  const totalEarnings = grossPay + overtimeBonus;
  const totalDeductions = advances + otherDeductions;
  const netPayout = totalEarnings - totalDeductions;

  const animatedPayout = useAnimatedCount(netPayout);

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleNumericInput = useCallback(
    (setter: React.Dispatch<React.SetStateAction<number>>) =>
      (e: React.ChangeEvent<HTMLInputElement>) => {
        const v = parseInt(e.target.value, 10);
        setter(isNaN(v) ? 0 : Math.max(0, v));
      },
    []
  );

  const inputClass =
    'w-full bg-trackify-card border border-trackify-cardBorder rounded-lg px-4 py-2 text-trackify-textMain font-body text-sm focus:border-trackify-amber focus:ring-1 focus:ring-trackify-amber/30 outline-none transition-colors';

  return (
    <div className="space-y-6">
      {/* Inputs Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {/* Worker Role Dropdown */}
        <div className="sm:col-span-2" ref={dropdownRef}>
          <label className="block font-mono text-sm text-trackify-textMuted mb-1.5">
            worker_role
          </label>
          <div className="relative">
            <button
              type="button"
              onClick={() => setDropdownOpen(!dropdownOpen)}
              className={`${inputClass} flex items-center justify-between cursor-pointer`}
              aria-haspopup="listbox"
              aria-expanded={dropdownOpen}
              aria-label="Select worker role"
            >
              <span>
                {selectedRole.name}{' '}
                <span className="text-trackify-textMuted">
                  — {formatINR(selectedRole.dailyRate)}/day
                </span>
              </span>
              <ChevronDown
                className={`w-4 h-4 text-trackify-textMuted transition-transform ${
                  dropdownOpen ? 'rotate-180' : ''
                }`}
              />
            </button>
            <AnimatePresence>
              {dropdownOpen && (
                <motion.ul
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.15 }}
                  className="absolute z-20 mt-1 w-full bg-trackify-card border border-trackify-cardBorder rounded-lg shadow-xl overflow-hidden"
                  role="listbox"
                  aria-label="Worker roles"
                >
                  {workerRoles.map((role) => (
                    <li
                      key={role.name}
                      role="option"
                      aria-selected={role.name === selectedRole.name}
                      className={`px-4 py-2.5 cursor-pointer text-sm transition-colors hover:bg-trackify-amber/10 ${
                        role.name === selectedRole.name
                          ? 'bg-trackify-amber/5 text-trackify-amber'
                          : 'text-trackify-textMain'
                      }`}
                      onClick={() => {
                        setSelectedRole(role);
                        setDropdownOpen(false);
                      }}
                    >
                      {role.name}{' '}
                      <span className="text-trackify-textMuted font-mono text-xs">
                        {formatINR(role.dailyRate)}/day
                      </span>
                    </li>
                  ))}
                </motion.ul>
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* Days Worked Slider */}
        <div className="sm:col-span-2">
          <label className="block font-mono text-sm text-trackify-textMuted mb-1.5">
            days_worked
          </label>
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={0}
              max={7}
              step={0.25}
              value={daysWorked}
              onChange={(e) => setDaysWorked(parseFloat(e.target.value))}
              className="flex-1 h-2 rounded-full appearance-none cursor-pointer accent-trackify-amber bg-trackify-cardBorder [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-trackify-amber [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:shadow-lg [&::-webkit-slider-thumb]:shadow-trackify-amber/30"
              aria-label="Days worked"
            />
            <span className="font-mono text-lg text-trackify-amber font-semibold min-w-[3rem] text-right">
              {daysWorked}
            </span>
          </div>
          <div className="flex justify-between mt-1 font-mono text-xs text-trackify-textMuted">
            <span>0</span>
            <span>7 days</span>
          </div>
        </div>

        {/* Overtime Bonus */}
        <div>
          <label className="block font-mono text-sm text-trackify-textMuted mb-1.5">
            overtime_bonus (₹)
          </label>
          <input
            type="number"
            min={0}
            value={overtimeBonus || ''}
            onChange={handleNumericInput(setOvertimeBonus)}
            placeholder="0"
            className={inputClass}
            aria-label="Overtime bonus in rupees"
          />
        </div>

        {/* Advances Taken */}
        <div>
          <label className="block font-mono text-sm text-trackify-textMuted mb-1.5">
            advances_taken (₹)
          </label>
          <input
            type="number"
            min={0}
            value={advances || ''}
            onChange={handleNumericInput(setAdvances)}
            placeholder="0"
            className={inputClass}
            aria-label="Advances taken in rupees"
          />
        </div>

        {/* Other Deductions */}
        <div>
          <label className="block font-mono text-sm text-trackify-textMuted mb-1.5">
            other_deductions (₹)
          </label>
          <input
            type="number"
            min={0}
            value={otherDeductions || ''}
            onChange={handleNumericInput(setOtherDeductions)}
            placeholder="0"
            className={inputClass}
            aria-label="Other deductions in rupees"
          />
        </div>
      </div>

      {/* Formula Display */}
      <div className="bg-trackify-darkSurface/60 border border-trackify-cardBorder/50 rounded-lg p-4">
        <p className="font-mono text-xs text-trackify-textMuted mb-1 font-semibold uppercase tracking-wider">Calculation Formula</p>
        <p className="font-mono text-sm text-trackify-cyan leading-relaxed">
          Net Payout = (Total Days × Daily Wage) + Overtime − Advances − Deductions
        </p>
        <p className="font-mono text-xs text-trackify-textMuted mt-2">
          = ({daysWorked} × {formatINR(selectedRole.dailyRate)}) + {formatINR(overtimeBonus)} −{' '}
          {formatINR(advances)} − {formatINR(otherDeductions)}
        </p>
      </div>

      {/* Result Display */}
      <motion.div
        layout
        className="bg-trackify-darkSurface/40 border border-trackify-cardBorder rounded-xl p-6 text-center"
      >
        <p className="font-mono text-xs text-trackify-textMuted mb-2 uppercase tracking-wider">
          net_payout
        </p>
        <motion.p
          key={netPayout}
          className={`font-heading text-4xl sm:text-5xl font-bold ${
            netPayout >= 0 ? 'text-trackify-emerald' : 'text-red-400'
          }`}
          aria-live="polite"
        >
          {formatINR(animatedPayout)}
        </motion.p>

        {/* Status Toggles */}
        <div className="flex items-center justify-center gap-2 mt-4 flex-wrap">
          {(Object.entries(statusConfig) as [PaymentStatus, typeof statusConfig[PaymentStatus]][]).map(
            ([key, config]) => (
              <button
                key={key}
                onClick={() => setPaymentStatus(key)}
                className={`px-3 py-1.5 rounded-lg text-xs font-mono border transition-all ${
                  paymentStatus === key
                    ? config.bg + ' ' + config.color
                    : 'border-trackify-cardBorder text-trackify-textMuted hover:border-trackify-textMuted/40'
                }`}
                aria-pressed={paymentStatus === key}
                aria-label={`Set status to ${config.label}`}
              >
                {config.label}
              </button>
            )
          )}
        </div>
      </motion.div>

      {/* Breakdown Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-sm" aria-label="Payroll breakdown">
          <thead>
            <tr className="border-b border-trackify-cardBorder">
              <th className="text-left py-2 px-3 font-mono text-xs text-trackify-textMuted font-normal uppercase tracking-wider">
                Item
              </th>
              <th className="text-right py-2 px-3 font-mono text-xs text-trackify-textMuted font-normal uppercase tracking-wider">
                Amount
              </th>
            </tr>
          </thead>
          <tbody className="font-body">
            <tr className="border-b border-trackify-cardBorder/50">
              <td className="py-2.5 px-3 text-trackify-textMain">
                Gross Pay{' '}
                <span className="text-trackify-textMuted font-mono text-xs">
                  ({daysWorked}d × {formatINR(selectedRole.dailyRate)})
                </span>
              </td>
              <td className="py-2.5 px-3 text-right text-trackify-textMain font-mono">
                {formatINR(grossPay)}
              </td>
            </tr>
            <tr className="border-b border-trackify-cardBorder/50">
              <td className="py-2.5 px-3 text-trackify-emerald">+ Overtime Bonus</td>
              <td className="py-2.5 px-3 text-right text-trackify-emerald font-mono">
                {formatINR(overtimeBonus)}
              </td>
            </tr>
            <tr className="border-b border-trackify-cardBorder/50">
              <td className="py-2.5 px-3 text-red-400">− Advances Taken</td>
              <td className="py-2.5 px-3 text-right text-red-400 font-mono">
                {formatINR(advances)}
              </td>
            </tr>
            <tr className="border-b border-trackify-cardBorder/50">
              <td className="py-2.5 px-3 text-red-400">− Other Deductions</td>
              <td className="py-2.5 px-3 text-right text-red-400 font-mono">
                {formatINR(otherDeductions)}
              </td>
            </tr>
            <tr>
              <td className="py-3 px-3 font-semibold text-trackify-textMain">Net Payout</td>
              <td
                className={`py-3 px-3 text-right font-mono font-bold text-lg ${
                  netPayout >= 0 ? 'text-trackify-emerald' : 'text-red-400'
                }`}
              >
                {formatINR(netPayout)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}
