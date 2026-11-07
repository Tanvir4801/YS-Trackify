import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Wifi, WifiOff, Cloud, CheckCircle2, Clock, ShieldCheck, Database, Smartphone } from 'lucide-react';

interface WorkerRecord {
  id: string;
  name: string;
  role: string;
  timestamp: string;
  status: 'pending' | 'syncing' | 'synced';
}

const initialWorkers = [
  { id: 'w1', name: 'Ramesh Patel', role: 'Mason Head', marked: false },
  { id: 'w2', name: 'Sunil Kumar', role: 'Helper Lead', marked: false },
  { id: 'w3', name: 'Meera Devi', role: 'Tile Specialist', marked: false },
  { id: 'w4', name: 'Vikram Singh', role: 'Bar Bender', marked: false },
];

export default function OfflineSimulator() {
  const [isOnline, setIsOnline] = useState(false);
  const [workers, setWorkers] = useState(initialWorkers);
  const [buffer, setBuffer] = useState<WorkerRecord[]>([
    {
      id: 'rec-01',
      name: 'Ramesh Patel',
      role: 'Mason Head',
      timestamp: '08:42:15 AM',
      status: 'pending',
    },
    {
      id: 'rec-02',
      name: 'Sunil Kumar',
      role: 'Helper Lead',
      timestamp: '08:43:02 AM',
      status: 'pending',
    },
  ]);
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncedCount, setSyncedCount] = useState(14);

  const toggleOnline = () => {
    const nextState = !isOnline;
    setIsOnline(nextState);

    if (nextState && buffer.some((r) => r.status === 'pending')) {
      setIsSyncing(true);
      // Simulate sync transition
      setBuffer((prev) => prev.map((r) => ({ ...r, status: 'syncing' })));

      setTimeout(() => {
        setBuffer((prev) => prev.map((r) => ({ ...r, status: 'synced' })));
        setSyncedCount((prev) => prev + buffer.length);
        setIsSyncing(false);
      }, 1200);
    }
  };

  const handleMarkAttendance = (workerId: string) => {
    const worker = workers.find((w) => w.id === workerId);
    if (!worker) return;

    setWorkers((prev) =>
      prev.map((w) => (w.id === workerId ? { ...w, marked: true } : w))
    );

    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true,
    });

    const newRecord: WorkerRecord = {
      id: `rec-${Date.now()}`,
      name: worker.name,
      role: worker.role,
      timestamp: timeStr,
      status: isOnline ? 'synced' : 'pending',
    };

    setBuffer((prev) => [newRecord, ...prev]);
    if (isOnline) {
      setSyncedCount((c) => c + 1);
    }
  };

  const resetDemo = () => {
    setWorkers(initialWorkers);
    setBuffer([
      {
        id: 'rec-01',
        name: 'Ramesh Patel',
        role: 'Mason Head',
        timestamp: '08:42:15 AM',
        status: isOnline ? 'synced' : 'pending',
      },
    ]);
  };

  const pendingCount = buffer.filter((r) => r.status === 'pending').length;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
      {/* ── Left Column: Architecture Context & Controls ── */}
      <div className="lg:col-span-5 space-y-6">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-trackify-cyan/10 border border-trackify-cyan/30 text-trackify-cyan text-xs font-mono mb-3">
            <Database className="w-3.5 h-3.5" />
            <span>SQLite Local Buffer + Firebase Sync</span>
          </div>
          <h3 className="font-heading text-2xl font-bold text-trackify-textMain">
            Basement or Remote Site? Zero Interruption.
          </h3>
          <p className="text-sm text-trackify-textMuted mt-2 leading-relaxed">
            Construction sites frequently lack 4G/5G signal inside basements, tunnels, or newly excavated foundations. Trackify queues all cryptographic muster stamps in AES-256 encrypted local device storage and synchronizes automatically with zero duplicate writes upon network handshake.
          </p>
        </div>

        {/* Toggle Switch */}
        <div className="p-4 rounded-xl bg-trackify-card border border-trackify-cardBorder flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div
              className={`w-10 h-10 rounded-lg flex items-center justify-center transition-colors ${
                isOnline
                  ? 'bg-trackify-emerald/20 text-trackify-emerald border border-trackify-emerald/40'
                  : 'bg-red-500/20 text-red-400 border border-red-500/40'
              }`}
            >
              {isOnline ? <Wifi className="w-5 h-5" /> : <WifiOff className="w-5 h-5" />}
            </div>
            <div>
              <p className="text-sm font-semibold text-trackify-textMain">
                Cellular Network Simulator
              </p>
              <p className="text-xs font-mono text-trackify-textMuted">
                Status: {isOnline ? (
                  <span className="text-trackify-emerald">ONLINE (4G VoLTE Active)</span>
                ) : (
                  <span className="text-red-400">OFFLINE (Zero Signal / Basement)</span>
                )}
              </p>
            </div>
          </div>

          <button
            onClick={toggleOnline}
            type="button"
            className={`relative inline-flex h-7 w-14 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-trackify-amber focus:ring-offset-2 focus:ring-offset-trackify-bg ${
              isOnline ? 'bg-trackify-emerald' : 'bg-gray-700'
            }`}
            aria-label="Toggle network status"
          >
            <span
              className={`pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                isOnline ? 'translate-x-7' : 'translate-x-0'
              }`}
            />
          </button>
        </div>

        {/* Telemetry Stat Cards */}
        <div className="grid grid-cols-2 gap-3">
          <div className="p-3.5 rounded-lg bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono text-trackify-textMuted">Local Buffer</span>
              <Clock className="w-3.5 h-3.5 text-trackify-amber" />
            </div>
            <p className="text-xl font-heading font-bold text-trackify-textMain mt-1">
              {pendingCount}{' '}
              <span className="text-xs font-normal text-trackify-textMuted">queued</span>
            </p>
            <p className="text-[11px] text-trackify-textMuted mt-0.5">Encrypted locally</p>
          </div>

          <div className="p-3.5 rounded-lg bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono text-trackify-textMuted">Cloud Verified</span>
              <Cloud className="w-3.5 h-3.5 text-trackify-emerald" />
            </div>
            <p className="text-xl font-heading font-bold text-trackify-emerald mt-1">
              {syncedCount}{' '}
              <span className="text-xs font-normal text-trackify-textMuted">reconciled</span>
            </p>
            <p className="text-[11px] text-trackify-textMuted mt-0.5">Master ledger synced</p>
          </div>
        </div>

        <button
          onClick={resetDemo}
          className="text-xs font-mono text-trackify-textMuted hover:text-trackify-amber transition-colors underline decoration-dotted"
        >
          ↻ Reset simulator state
        </button>
      </div>

      {/* ── Right Column: Interactive Phone Mockup ── */}
      <div className="lg:col-span-7 flex justify-center">
        <div className="w-full max-w-[340px] sm:max-w-[380px] rounded-[36px] p-3.5 bg-gradient-to-b from-[#1F2D44] via-[#0E1726] to-[#0A101D] border-2 border-white/[0.12] shadow-2xl relative">
          {/* Phone Speaker Notch */}
          <div className="absolute top-5 left-1/2 -translate-x-1/2 w-28 h-4 bg-[#080E1A] rounded-full flex items-center justify-center gap-2 z-20">
            <div className="w-2.5 h-2.5 rounded-full bg-trackify-cardBorder" />
            <div className="w-8 h-1.5 rounded-full bg-trackify-cardBorder" />
          </div>

          {/* Screen Container */}
          <div className="rounded-[28px] bg-trackify-bg border border-white/[0.06] overflow-hidden pt-8 pb-4 px-3.5 relative">
            {/* Phone App Header */}
            <div className="flex items-center justify-between pb-3 border-b border-white/[0.08] mb-3">
              <div className="flex items-center gap-2">
                <Smartphone className="w-4 h-4 text-trackify-amber" />
                <span className="font-heading font-bold text-xs text-trackify-textMain">
                  Trackify Site App v1.4
                </span>
              </div>
              <div
                className={`flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-mono ${
                  isOnline
                    ? 'bg-trackify-emerald/20 text-trackify-emerald'
                    : 'bg-red-500/20 text-red-400'
                }`}
              >
                <span
                  className={`w-1.5 h-1.5 rounded-full ${
                    isOnline ? 'bg-trackify-emerald animate-ping' : 'bg-red-400'
                  }`}
                />
                {isOnline ? 'ONLINE' : 'OFFLINE'}
              </div>
            </div>

            {/* Quick Action: Tap to Mark */}
            <div className="mb-3">
              <p className="text-[11px] font-mono uppercase tracking-wider text-trackify-textMuted mb-2">
                Active Site: Greenfield Villa #345
              </p>
              <div className="space-y-2">
                {workers.map((worker) => (
                  <div
                    key={worker.id}
                    className="flex items-center justify-between p-2 rounded-lg bg-white/[0.03] border border-white/[0.06] hover:border-trackify-cardBorder transition-colors"
                  >
                    <div>
                      <p className="text-xs font-semibold text-trackify-textMain">{worker.name}</p>
                      <p className="text-[10px] font-mono text-trackify-textMuted">{worker.role}</p>
                    </div>

                    <button
                      onClick={() => handleMarkAttendance(worker.id)}
                      className={`px-2.5 py-1 rounded text-[11px] font-medium transition-all ${
                        worker.marked
                          ? 'bg-trackify-emerald/20 text-trackify-emerald cursor-default border border-trackify-emerald/30'
                          : 'bg-trackify-amber text-trackify-bg hover:bg-trackify-amberDark active:scale-95'
                      }`}
                    >
                      {worker.marked ? '✓ Present' : 'Mark Tap'}
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Local Buffer Queue View */}
            <div className="mt-4 pt-3 border-t border-white/[0.08]">
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono uppercase text-trackify-textMuted flex items-center gap-1">
                  <ShieldCheck className="w-3 h-3 text-trackify-cyan" />
                  Local Sync Buffer
                </span>
                <span className="text-[10px] font-mono text-trackify-amber">
                  {pendingCount} waiting
                </span>
              </div>

              {/* Syncing Indicator */}
              <AnimatePresence>
                {isSyncing && (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    className="p-2 mb-2 rounded bg-trackify-cyan/10 border border-trackify-cyan/30 flex items-center gap-2 text-trackify-cyan text-[11px] font-mono"
                  >
                    <Cloud className="w-3.5 h-3.5 animate-bounce" />
                    <span>Transmitting buffered payload to cloud...</span>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Buffer Items */}
              <div className="space-y-1.5 max-h-[140px] overflow-y-auto pr-1">
                <AnimatePresence initial={false}>
                  {buffer.slice(0, 4).map((rec) => (
                    <motion.div
                      key={rec.id}
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, scale: 0.9 }}
                      className={`p-2 rounded flex items-center justify-between text-[11px] ${
                        rec.status === 'synced'
                          ? 'bg-trackify-emerald/10 border border-trackify-emerald/20 text-trackify-textMain'
                          : 'bg-trackify-card border border-trackify-cardBorder text-trackify-textMuted'
                      }`}
                    >
                      <div className="truncate">
                        <span className="font-semibold text-trackify-textMain mr-1.5">{rec.name}</span>
                        <span className="font-mono text-[9px] text-trackify-textMuted">
                          {rec.timestamp}
                        </span>
                      </div>
                      <div className="flex items-center gap-1 font-mono text-[10px] flex-shrink-0">
                        {rec.status === 'synced' ? (
                          <span className="text-trackify-emerald flex items-center gap-0.5">
                            <CheckCircle2 className="w-3 h-3" /> Synced
                          </span>
                        ) : rec.status === 'syncing' ? (
                          <span className="text-trackify-cyan flex items-center gap-0.5 animate-pulse">
                            Syncing...
                          </span>
                        ) : (
                          <span className="text-trackify-amber flex items-center gap-0.5">
                            <Clock className="w-3 h-3" /> Buffered
                          </span>
                        )}
                      </div>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

