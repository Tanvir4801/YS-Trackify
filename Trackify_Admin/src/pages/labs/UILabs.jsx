import React, { useState } from 'react';
import { FileCode, Palette, ArrowLeft, Maximize2, Smartphone, Monitor, Code, Package, Database, RefreshCw, ShieldAlert } from 'lucide-react';

export default function UILabs() {
  const [activeView, setActiveView] = useState(null);

  const concepts = [
    { id: 'material', name: 'Material Management UI', type: 'desktop', desc: 'Inventory tracking, purchase orders, and site-to-site transfers.' },
    { id: 'dashboard_v3', name: 'Supervisor Dashboard V3', type: 'mobile', desc: 'Streamlined daily workflow for supervisors on the ground.' },
    { id: 'labour_app', name: 'Labour App V4', type: 'mobile', desc: 'Self-service app for labours to check their own attendance and advances.' },
    { id: 'reports', name: 'Reports UI', type: 'desktop', desc: 'Advanced pivot tables and charting for contractor analytics.' },
    { id: 'trackops', name: 'TrackOps UI V2', type: 'desktop', desc: 'Next-gen mission control with 3D globe and live socket visualizer.' }
  ];

  if (activeView) {
    const concept = concepts.find(c => c.id === activeView);
    return (
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
          <div className="flex items-center">
            <button 
              onClick={() => setActiveView(null)}
              className="mr-4 p-2 rounded-lg bg-[#121214] border border-[#27272a] text-gray-400 hover:text-white transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
            </button>
            <div>
              <h1 className="text-xl font-semibold tracking-wide text-white">{concept.name}</h1>
              <p className="text-xs text-gray-500 mt-1">{concept.desc}</p>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            <div className="flex items-center px-3 py-1.5 rounded-lg bg-[#121214] border border-[#27272a] text-xs text-gray-400">
              {concept.type === 'desktop' ? <Monitor className="w-3 h-3 mr-2" /> : <Smartphone className="w-3 h-3 mr-2" />}
              {concept.type.toUpperCase()} PREVIEW
            </div>
            <button className="p-2 rounded-lg bg-[#121214] border border-[#27272a] text-gray-400 hover:text-cyan-400 transition-colors">
              <Code className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Mockup Canvas */}
        <div className="bg-[#121214] border border-[#27272a] rounded-xl p-8 flex items-center justify-center min-h-[600px] overflow-hidden relative">
          <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-[0.03]" />
          
          {concept.type === 'desktop' ? (
            <DesktopMockup conceptId={concept.id} title={concept.name} />
          ) : (
            <MobileMockup conceptId={concept.id} title={concept.name} />
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-5xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-tight flex items-center">
            <Palette className="w-6 h-6 mr-3 text-cyan-400" />
            UI Labs
          </h1>
          <p className="text-gray-400 text-sm mt-1">Experimental interfaces and future design concepts.</p>
        </div>
        <div className="px-3 py-1 bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 rounded-full text-xs font-semibold flex items-center">
          <div className="w-1.5 h-1.5 rounded-full bg-cyan-400 mr-2 animate-pulse" />
          5 Concepts Available
        </div>
      </div>

      <div className="grid grid-cols-2 gap-6">
        {concepts.map((concept, i) => (
          <div 
            key={i}
            className="group bg-[#121214] border border-[#27272a] hover:border-cyan-500/50 rounded-xl p-6 transition-all duration-300 cursor-pointer shadow-lg hover:shadow-[0_0_30px_rgba(6,182,212,0.1)] relative overflow-hidden flex flex-col"
            onClick={() => setActiveView(concept.id)}
          >
            <div className="absolute top-0 right-0 w-32 h-32 bg-cyan-500/5 rounded-full blur-3xl -mr-16 -mt-16 group-hover:bg-cyan-500/10 transition-colors" />
            
            <div className="flex justify-between items-start mb-4 relative z-10">
              <div className="p-3 bg-[#1e1e24] rounded-lg border border-[#27272a] group-hover:border-cyan-500/30 transition-colors">
                {concept.type === 'desktop' ? <Monitor className="w-5 h-5 text-gray-400 group-hover:text-cyan-400" /> : <Smartphone className="w-5 h-5 text-gray-400 group-hover:text-cyan-400" />}
              </div>
              <div className="flex space-x-2 opacity-0 group-hover:opacity-100 transition-opacity">
                <button className="p-1.5 bg-[#27272a] rounded text-gray-400 hover:text-white">
                  <Maximize2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            <h3 className="text-lg font-bold text-white mb-2 relative z-10">{concept.name}</h3>
            <p className="text-sm text-gray-400 mb-6 flex-1 relative z-10 line-clamp-2">{concept.desc}</p>
            
            <div className="mt-auto flex items-center justify-between border-t border-[#27272a] pt-4 relative z-10">
              <span className="text-[10px] font-mono text-cyan-500 tracking-wider uppercase flex items-center">
                Preview <ArrowLeft className="w-3 h-3 ml-1 rotate-180" />
              </span>
              <span className="text-[10px] text-gray-600 font-mono tracking-widest">{concept.type.toUpperCase()}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── DUMMY MOCKUP COMPONENTS ──────────────────────────────────────────────────

function DesktopMockup({ conceptId, title }) {
  return (
    <div className="w-full max-w-4xl bg-[#09090b] rounded-lg border border-[#27272a] shadow-2xl overflow-hidden relative z-10 flex flex-col h-[500px]">
      {/* Mac Window Header */}
      <div className="h-8 bg-[#121214] border-b border-[#27272a] flex items-center px-4 space-x-2">
        <div className="w-3 h-3 rounded-full bg-red-500/80" />
        <div className="w-3 h-3 rounded-full bg-amber-500/80" />
        <div className="w-3 h-3 rounded-full bg-green-500/80" />
        <div className="mx-auto text-[10px] text-gray-500 font-mono tracking-widest uppercase absolute left-1/2 -translate-x-1/2">{title}</div>
      </div>
      
      {/* Mockup Body based on Concept */}
      <div className="flex-1 p-6 relative">
        {conceptId === 'material' && (
          <div className="h-full flex space-x-6 text-white font-sans animate-in fade-in duration-700">
            {/* Sidebar */}
            <div className="w-56 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-4 flex flex-col shadow-xl">
              <div className="flex items-center space-x-2 mb-8 px-2">
                <div className="w-8 h-8 rounded bg-gradient-to-br from-cyan-500 to-blue-600 flex items-center justify-center shadow-[0_0_15px_rgba(6,182,212,0.4)]">
                  <Package className="w-4 h-4 text-white" />
                </div>
                <span className="font-bold tracking-wider text-sm">STOCK OPS</span>
              </div>
              
              <div className="space-y-2 flex-1">
                <div className="px-3 py-2 rounded-lg bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 text-xs font-medium flex items-center cursor-pointer transition-all hover:bg-cyan-500/20">
                  <Database className="w-4 h-4 mr-3" /> Inventory
                </div>
                <div className="px-3 py-2 rounded-lg text-gray-400 text-xs font-medium flex items-center cursor-pointer transition-all hover:bg-[#27272a] hover:text-white">
                  <FileCode className="w-4 h-4 mr-3" /> Purchase Orders
                </div>
                <div className="px-3 py-2 rounded-lg text-gray-400 text-xs font-medium flex items-center cursor-pointer transition-all hover:bg-[#27272a] hover:text-white">
                  <RefreshCw className="w-4 h-4 mr-3" /> Site Transfers
                </div>
                <div className="px-3 py-2 rounded-lg text-gray-400 text-xs font-medium flex items-center cursor-pointer transition-all hover:bg-[#27272a] hover:text-white">
                  <ShieldAlert className="w-4 h-4 mr-3" /> Audit Logs
                </div>
              </div>
              
              <div className="mt-auto p-3 rounded-lg bg-gradient-to-br from-[#1e1e24] to-[#121214] border border-[#27272a]">
                <div className="text-[10px] text-gray-500 uppercase tracking-widest mb-1">System Status</div>
                <div className="flex items-center text-xs text-green-400">
                  <div className="w-2 h-2 rounded-full bg-green-500 mr-2 shadow-[0_0_8px_#22c55e] animate-pulse" />
                  Live Sync Active
                </div>
              </div>
            </div>

            {/* Main Area */}
            <div className="flex-1 flex flex-col space-y-4">
              {/* Top Stats */}
              <div className="flex space-x-4">
                <div className="flex-1 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-4 shadow-xl">
                  <div className="text-gray-400 text-xs mb-1 uppercase tracking-wider">Total Value</div>
                  <div className="text-2xl font-semibold text-white">₹ 14.5M</div>
                  <div className="text-[10px] text-green-400 mt-1">+12% vs last month</div>
                </div>
                <div className="flex-1 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-4 shadow-xl">
                  <div className="text-gray-400 text-xs mb-1 uppercase tracking-wider">Low Stock Alerts</div>
                  <div className="text-2xl font-semibold text-white">8 <span className="text-sm text-gray-500 font-normal">items</span></div>
                  <div className="text-[10px] text-red-400 mt-1">Requires immediate action</div>
                </div>
                <div className="flex-1 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-4 shadow-xl">
                  <div className="text-gray-400 text-xs mb-1 uppercase tracking-wider">Pending POs</div>
                  <div className="text-2xl font-semibold text-white">12</div>
                  <div className="text-[10px] text-amber-400 mt-1">₹ 2.1M pending approval</div>
                </div>
              </div>

              {/* Table Area */}
              <div className="flex-1 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-5 shadow-xl flex flex-col">
                <div className="flex justify-between items-center mb-6">
                  <div className="text-sm font-semibold tracking-wide">Inventory Overview</div>
                  <button className="px-3 py-1.5 bg-cyan-500 hover:bg-cyan-400 text-black text-xs font-semibold rounded transition-colors shadow-[0_0_10px_rgba(6,182,212,0.3)]">
                    + Add Item
                  </button>
                </div>

                <div className="flex-1 border border-[#27272a] rounded-lg overflow-hidden flex flex-col">
                  {/* Table Header */}
                  <div className="bg-[#1e1e24] grid grid-cols-4 px-4 py-2 border-b border-[#27272a] text-[10px] uppercase tracking-wider text-gray-500 font-semibold">
                    <div>Item Code</div>
                    <div>Category</div>
                    <div>Quantity</div>
                    <div>Status</div>
                  </div>
                  {/* Table Rows */}
                  <div className="flex-1 overflow-y-auto">
                    {[
                      { code: 'CEMT-53G', cat: 'Raw Material', qty: '450 Bags', stat: 'Optimal' },
                      { code: 'STEL-TMT', cat: 'Raw Material', qty: '12 Tons', stat: 'Low' },
                      { code: 'BRCK-RED', cat: 'Construction', qty: '15000 Pcs', stat: 'Optimal' },
                      { code: 'WDN-PLNK', cat: 'Scaffolding', qty: '45 Units', stat: 'Critical' },
                    ].map((row, i) => (
                      <div key={i} className="grid grid-cols-4 px-4 py-3 border-b border-[#27272a] text-xs text-gray-300 hover:bg-[#1e1e24] transition-colors cursor-default">
                        <div className="font-mono text-cyan-400">{row.code}</div>
                        <div>{row.cat}</div>
                        <div>{row.qty}</div>
                        <div>
                          <span className={`px-2 py-0.5 rounded text-[10px] font-semibold ${
                            row.stat === 'Optimal' ? 'bg-green-500/20 text-green-400' :
                            row.stat === 'Low' ? 'bg-amber-500/20 text-amber-400' :
                            'bg-red-500/20 text-red-400'
                          }`}>
                            {row.stat}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {conceptId === 'reports' && (
          <div className="h-full flex flex-col text-white font-sans animate-in fade-in duration-700">
            {/* Toolbar */}
            <div className="flex justify-between items-center mb-6 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-3 shadow-xl">
              <div className="flex space-x-2">
                <button className="px-3 py-1.5 bg-[#27272a] text-xs rounded border border-[#3f3f46] hover:bg-[#3f3f46] transition-colors">Cost Analysis</button>
                <button className="px-3 py-1.5 text-gray-400 text-xs rounded hover:bg-[#27272a] transition-colors">Labour Trends</button>
                <button className="px-3 py-1.5 text-gray-400 text-xs rounded hover:bg-[#27272a] transition-colors">Site Comparison</button>
              </div>
              <div className="flex space-x-2">
                <button className="px-3 py-1.5 bg-indigo-500/20 text-indigo-400 text-xs font-semibold rounded border border-indigo-500/30 hover:bg-indigo-500/30 transition-colors">
                  Export PDF
                </button>
                <button className="px-3 py-1.5 bg-emerald-500/20 text-emerald-400 text-xs font-semibold rounded border border-emerald-500/30 hover:bg-emerald-500/30 transition-colors">
                  Export CSV
                </button>
              </div>
            </div>

            {/* Dashboard Area */}
            <div className="flex-1 grid grid-cols-3 gap-6">
              {/* Main Chart Area */}
              <div className="col-span-2 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-5 shadow-xl flex flex-col relative overflow-hidden">
                <div className="absolute -right-20 -top-20 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />
                
                <div className="text-sm font-semibold tracking-wide mb-6">Cumulative Project Cost over Time</div>
                
                <div className="flex-1 flex items-end justify-between px-2 pt-10 relative">
                  {/* Grid Lines */}
                  <div className="absolute inset-0 flex flex-col justify-between pt-14 pb-8 px-2 pointer-events-none">
                    {[1, 2, 3, 4].map(i => (
                      <div key={i} className="w-full border-t border-[#27272a] opacity-50" />
                    ))}
                  </div>
                  
                  {/* Bars */}
                  {[40, 55, 48, 70, 65, 85, 95, 80, 100, 90, 110, 105].map((h, i) => (
                    <div key={i} className="relative group w-8">
                      <div 
                        className="w-full bg-gradient-to-t from-indigo-900/50 to-indigo-500 rounded-t-sm transition-all duration-500 group-hover:to-indigo-400 group-hover:shadow-[0_0_15px_rgba(99,102,241,0.5)] cursor-pointer"
                        style={{ height: `${h}%` }}
                      />
                      {/* Tooltip */}
                      <div className="absolute -top-10 left-1/2 -translate-x-1/2 bg-black text-[10px] py-1 px-2 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10 border border-[#27272a]">
                        ₹ {(h * 12500).toLocaleString()}
                      </div>
                    </div>
                  ))}
                </div>
                
                {/* X Axis */}
                <div className="flex justify-between px-2 mt-4 text-[9px] text-gray-500 uppercase font-mono">
                  <span>Jan</span>
                  <span>Feb</span>
                  <span>Mar</span>
                  <span>Apr</span>
                  <span>May</span>
                  <span>Jun</span>
                  <span>Jul</span>
                  <span>Aug</span>
                  <span>Sep</span>
                  <span>Oct</span>
                  <span>Nov</span>
                  <span>Dec</span>
                </div>
              </div>

              {/* Sidebar Stats */}
              <div className="col-span-1 flex flex-col space-y-6">
                <div className="bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-5 shadow-xl">
                  <div className="text-xs text-gray-400 mb-1">Total Labour Cost (YTD)</div>
                  <div className="text-3xl font-bold text-white mb-2">₹ 4.2M</div>
                  <div className="w-full bg-[#27272a] h-1.5 rounded-full overflow-hidden">
                    <div className="bg-indigo-500 w-[65%] h-full" />
                  </div>
                  <div className="text-[10px] text-gray-500 mt-2 text-right">65% of allocated budget</div>
                </div>

                <div className="flex-1 bg-[#121214]/80 backdrop-blur-md rounded-xl border border-[#27272a] p-5 shadow-xl flex flex-col">
                  <div className="text-sm font-semibold tracking-wide mb-4">Cost by Category</div>
                  
                  <div className="flex-1 flex flex-col justify-center space-y-4">
                    {[
                      { label: 'Skilled Labour', val: '45%', col: 'bg-indigo-500' },
                      { label: 'Unskilled Labour', val: '30%', col: 'bg-blue-500' },
                      { label: 'Supervisors', val: '15%', col: 'bg-cyan-500' },
                      { label: 'Overtime', val: '10%', col: 'bg-emerald-500' },
                    ].map((item, i) => (
                      <div key={i}>
                        <div className="flex justify-between text-xs mb-1">
                          <span className="text-gray-300">{item.label}</span>
                          <span className="text-gray-400 font-mono">{item.val}</span>
                        </div>
                        <div className="w-full bg-[#27272a] h-1 rounded-full overflow-hidden">
                          <div className={`${item.col} h-full`} style={{ width: item.val }} />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {conceptId === 'trackops' && (
          <div className="h-full flex flex-col text-white font-sans animate-in zoom-in-95 duration-700 relative">
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-blue-900/20 via-black/0 to-black/0 pointer-events-none" />
            
            {/* Top Bar */}
            <div className="flex justify-between items-center bg-[#121214]/60 backdrop-blur-xl border border-blue-500/20 rounded-lg p-3 shadow-[0_0_20px_rgba(59,130,246,0.1)] mb-4">
              <div className="flex items-center space-x-3">
                <div className="w-2 h-2 rounded-full bg-blue-500 animate-pulse shadow-[0_0_8px_#3b82f6]" />
                <span className="text-sm font-semibold tracking-widest text-blue-100">GLOBAL OPERATIONS</span>
              </div>
              <div className="flex space-x-4 text-[10px] font-mono text-blue-400">
                <div>ACTIVE NODES: <span className="text-white">1,204</span></div>
                <div>TOTAL SYNC: <span className="text-white">45.2 GB/s</span></div>
              </div>
            </div>

            {/* Main Viz Area (Fake 3D Globe Concept) */}
            <div className="flex-1 border border-[#27272a] rounded-lg bg-[#09090b] relative overflow-hidden flex items-center justify-center">
              
              {/* Fake Grid Floor */}
              <div className="absolute bottom-0 w-full h-1/2 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-10" style={{ transform: 'perspective(500px) rotateX(60deg)' }} />
              
              {/* Glowing Orb (Globe) */}
              <div className="w-64 h-64 rounded-full border border-blue-500/30 relative flex items-center justify-center shadow-[inset_0_0_50px_rgba(59,130,246,0.2),0_0_100px_rgba(59,130,246,0.1)]">
                {/* Latitude/Longitude lines */}
                <div className="absolute w-full h-full border border-blue-500/20 rounded-full" style={{ transform: 'rotateX(75deg)' }} />
                <div className="absolute w-full h-full border border-blue-500/20 rounded-full" style={{ transform: 'rotateY(75deg)' }} />
                <div className="absolute w-full h-full border border-blue-500/20 rounded-full" style={{ transform: 'rotateX(45deg) rotateY(45deg)' }} />
                
                {/* Node Points */}
                <div className="absolute top-1/4 left-1/4 w-1.5 h-1.5 bg-cyan-400 rounded-full shadow-[0_0_10px_#22d3ee] animate-ping" />
                <div className="absolute top-1/2 right-1/4 w-1.5 h-1.5 bg-blue-400 rounded-full shadow-[0_0_10px_#60a5fa] animate-pulse" />
                <div className="absolute bottom-1/3 left-1/2 w-2 h-2 bg-indigo-400 rounded-full shadow-[0_0_15px_#818cf8]" />
                
                {/* Connection lines (SVG overlay) */}
                <svg className="absolute inset-0 w-full h-full opacity-50" viewBox="0 0 100 100">
                  <path d="M25,25 Q50,0 75,50" fill="none" stroke="#60a5fa" strokeWidth="0.5" strokeDasharray="1,1" className="animate-[dash_5s_linear_infinite]" />
                  <path d="M50,66 Q75,100 75,50" fill="none" stroke="#22d3ee" strokeWidth="0.5" strokeDasharray="2,2" />
                </svg>
              </div>
              
              {/* Floating Panels */}
              <div className="absolute top-4 left-4 w-48 bg-[#121214]/80 backdrop-blur-md border border-[#27272a] rounded p-3 shadow-2xl text-xs font-mono">
                <div className="text-gray-500 mb-2">SYSTEM.LOG_STREAM</div>
                <div className="space-y-1 text-blue-300 opacity-80">
                  <div>&gt; Auth verified [OK]</div>
                  <div>&gt; Syncing node_x12...</div>
                  <div className="text-green-400">&gt; Data ingestion complete</div>
                  <div>&gt; Idle.</div>
                </div>
              </div>

              <div className="absolute bottom-4 right-4 w-56 bg-[#121214]/80 backdrop-blur-md border border-[#27272a] rounded p-3 shadow-2xl">
                <div className="text-[10px] text-gray-500 mb-2 font-mono">PERFORMANCE METRICS</div>
                <div className="space-y-2">
                  <div>
                    <div className="flex justify-between text-[10px] text-gray-400 mb-1"><span>CPU</span><span>42%</span></div>
                    <div className="w-full bg-[#27272a] h-1 rounded-full overflow-hidden"><div className="w-[42%] h-full bg-blue-500" /></div>
                  </div>
                  <div>
                    <div className="flex justify-between text-[10px] text-gray-400 mb-1"><span>MEM</span><span>78%</span></div>
                    <div className="w-full bg-[#27272a] h-1 rounded-full overflow-hidden"><div className="w-[78%] h-full bg-cyan-500" /></div>
                  </div>
                </div>
              </div>

            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function MobileMockup({ conceptId, title }) {
  return (
    <div className="w-[320px] h-[650px] bg-black rounded-[40px] border-[8px] border-[#1e1e24] shadow-[0_0_50px_rgba(0,0,0,0.5)] overflow-hidden relative z-10 flex flex-col">
      {/* Notch */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-[#1e1e24] rounded-b-xl z-20 flex justify-center items-center">
        <div className="w-12 h-1.5 bg-black rounded-full opacity-20" />
      </div>

      {/* Screen Area */}
      <div className="flex-1 bg-white relative">
        {conceptId === 'dashboard_v3' && (
          <div className="h-full bg-gray-50 flex flex-col animate-in slide-in-from-bottom-8 duration-500 font-sans">
            {/* Header */}
            <div className="bg-indigo-600 pt-12 pb-16 px-6 relative overflow-hidden rounded-b-[2.5rem] shadow-lg shrink-0">
              <div className="absolute -top-10 -right-10 w-32 h-32 bg-white/10 rounded-full blur-xl" />
              <div className="relative z-10 flex justify-between items-center text-white">
                <div>
                  <div className="text-indigo-200 text-xs font-medium">Site: Sunrise Towers</div>
                  <div className="text-xl font-bold tracking-tight mt-0.5">Hello, Shirish</div>
                </div>
                <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center backdrop-blur-sm border border-white/30">
                  <span className="font-bold">SP</span>
                </div>
              </div>
            </div>

            {/* Quick Actions (Overlapping Header) */}
            <div className="px-6 -mt-8 relative z-20 shrink-0">
              <div className="bg-white rounded-2xl shadow-xl p-4 flex justify-around border border-gray-100">
                <div className="flex flex-col items-center">
                  <div className="w-12 h-12 bg-indigo-50 text-indigo-600 rounded-full flex items-center justify-center mb-2 shadow-inner">
                    <Smartphone className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-semibold text-gray-600">Scan QR</span>
                </div>
                <div className="flex flex-col items-center">
                  <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-full flex items-center justify-center mb-2 shadow-inner">
                    <FileCode className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-semibold text-gray-600">Manual</span>
                </div>
                <div className="flex flex-col items-center">
                  <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-full flex items-center justify-center mb-2 shadow-inner">
                    <RefreshCw className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-semibold text-gray-600">Sync</span>
                </div>
              </div>
            </div>

            {/* Main Content Area (Scrollable) */}
            <div className="flex-1 overflow-y-auto px-6 py-6 pb-24 space-y-6">
              
              {/* Daily Progress */}
              <div>
                <h3 className="text-sm font-bold text-gray-800 mb-3 tracking-wide">Today's Progress</h3>
                <div className="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 relative overflow-hidden">
                  <div className="absolute top-0 right-0 w-16 h-16 bg-gradient-to-br from-indigo-50 to-white rounded-bl-full" />
                  <div className="flex justify-between items-end mb-3">
                    <div className="text-3xl font-black text-indigo-900 tracking-tighter">45<span className="text-sm font-medium text-gray-400 ml-1">/ 50</span></div>
                    <div className="text-xs font-bold text-emerald-500 bg-emerald-50 px-2 py-1 rounded-md mb-1">+2 overtime</div>
                  </div>
                  <div className="text-xs text-gray-500 font-medium mb-3">Labours Marked Present</div>
                  <div className="w-full bg-gray-100 h-2 rounded-full overflow-hidden">
                    <div className="bg-gradient-to-r from-indigo-400 to-indigo-600 w-[90%] h-full rounded-full" />
                  </div>
                </div>
              </div>

              {/* Recent Activity */}
              <div>
                <h3 className="text-sm font-bold text-gray-800 mb-3 tracking-wide">Recent Activity</h3>
                <div className="space-y-3">
                  {[
                    { n: 'Rahul Kumar', t: 'Present', time: '08:45 AM', col: 'bg-emerald-500' },
                    { n: 'Amit Singh', t: 'Half Day', time: '09:12 AM', col: 'bg-amber-500' },
                    { n: 'Vikram Patel', t: 'Absent', time: '09:30 AM', col: 'bg-red-500' },
                  ].map((act, i) => (
                    <div key={i} className="flex items-center p-3 bg-white rounded-xl border border-gray-100 shadow-[0_2px_10px_rgba(0,0,0,0.02)]">
                      <div className={`w-2 h-10 rounded-full ${act.col} mr-3`} />
                      <div className="flex-1">
                        <div className="text-sm font-bold text-gray-800">{act.n}</div>
                        <div className="text-[10px] text-gray-500 font-medium uppercase tracking-wider">{act.t}</div>
                      </div>
                      <div className="text-xs font-semibold text-gray-400">{act.time}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Bottom Nav Bar */}
            <div className="absolute bottom-0 w-full bg-white border-t border-gray-100 flex justify-around py-3 px-6 pb-6 shrink-0 shadow-[0_-10px_20px_rgba(0,0,0,0.02)] z-30">
              <div className="flex flex-col items-center text-indigo-600">
                <Database className="w-5 h-5 mb-1" />
                <span className="text-[9px] font-bold">Home</span>
              </div>
              <div className="flex flex-col items-center text-gray-400 hover:text-gray-600 transition-colors">
                <FileCode className="w-5 h-5 mb-1" />
                <span className="text-[9px] font-bold">Log</span>
              </div>
              <div className="flex flex-col items-center text-gray-400 hover:text-gray-600 transition-colors">
                <ShieldAlert className="w-5 h-5 mb-1" />
                <span className="text-[9px] font-bold">Alerts</span>
              </div>
              <div className="flex flex-col items-center text-gray-400 hover:text-gray-600 transition-colors">
                <Smartphone className="w-5 h-5 mb-1" />
                <span className="text-[9px] font-bold">Profile</span>
              </div>
            </div>
          </div>
        )}

        {conceptId === 'labour_app' && (
          <div className="h-full bg-[#111111] flex flex-col animate-in slide-in-from-bottom-8 duration-500 font-sans text-white">
            
            {/* Dark Mode Header */}
            <div className="p-6 pt-12 pb-8 flex justify-between items-center relative overflow-hidden shrink-0">
               {/* Abstract background blobs */}
               <div className="absolute top-0 right-0 w-48 h-48 bg-amber-500/10 rounded-full blur-3xl" />
               <div className="absolute -left-10 -bottom-10 w-32 h-32 bg-orange-500/10 rounded-full blur-2xl" />
               
               <div className="relative z-10">
                 <div className="text-gray-400 text-xs font-medium tracking-wide">ID: LBR-8291</div>
                 <div className="text-2xl font-black mt-1 tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-amber-400 to-orange-500">
                   Ramesh Bhai
                 </div>
               </div>
               
               <div className="w-12 h-12 rounded-2xl bg-[#1a1a1a] border border-[#2a2a2a] flex items-center justify-center relative z-10 shadow-lg">
                 <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Ramesh&backgroundColor=transparent" alt="avatar" className="w-10 h-10" />
               </div>
            </div>

            {/* Main Content Area (Scrollable) */}
            <div className="flex-1 overflow-y-auto px-6 space-y-6 pb-24">
              
              {/* Virtual ID Card */}
              <div className="w-full aspect-[1.6] bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] rounded-3xl border border-[#333] p-5 shadow-2xl relative overflow-hidden group">
                <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')] opacity-20 mix-blend-overlay" />
                {/* Shine effect */}
                <div className="absolute top-0 -left-[100%] w-1/2 h-full bg-gradient-to-r from-transparent via-white/5 to-transparent transform skew-x-[-20deg] group-hover:left-[200%] transition-all duration-1000 ease-in-out" />
                
                <div className="flex justify-between items-start relative z-10 h-full">
                  <div className="flex flex-col h-full justify-between">
                    <div>
                      <div className="text-[10px] font-bold tracking-widest text-gray-500 uppercase">Trackify Worker Pass</div>
                      <div className="text-amber-500 font-bold text-lg mt-1 tracking-wide">Skilled Mason</div>
                    </div>
                    
                    <div>
                      <div className="text-xs text-gray-400 mb-0.5">Contractor</div>
                      <div className="font-semibold text-sm">YS Construction Ltd.</div>
                    </div>
                  </div>
                  
                  {/* QR Code Placeholder */}
                  <div className="w-20 h-20 bg-white rounded-xl p-1.5 shadow-[0_0_15px_rgba(251,191,36,0.15)] flex-shrink-0">
                    <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=LBR-8291" alt="QR" className="w-full h-full opacity-90" />
                  </div>
                </div>
              </div>

              {/* Stats Grid */}
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-2xl p-4">
                  <div className="text-gray-400 text-xs font-medium mb-1">Days Worked</div>
                  <div className="text-2xl font-black text-white">22 <span className="text-sm font-normal text-gray-500">/ 30</span></div>
                  <div className="text-[10px] text-emerald-400 mt-2 font-semibold">↑ On track</div>
                </div>
                <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-2xl p-4">
                  <div className="text-gray-400 text-xs font-medium mb-1">Est. Earnings</div>
                  <div className="text-2xl font-black text-white">₹ 13.2k</div>
                  <div className="text-[10px] text-gray-500 mt-2 font-semibold">At ₹600/day</div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="space-y-3">
                <button className="w-full bg-[#1a1a1a] hover:bg-[#222] border border-[#2a2a2a] rounded-2xl p-4 flex items-center justify-between transition-colors">
                  <div className="flex items-center">
                    <div className="w-10 h-10 rounded-full bg-amber-500/10 flex items-center justify-center text-amber-500 mr-4">
                      <RefreshCw className="w-5 h-5" />
                    </div>
                    <div className="text-left">
                      <div className="font-bold text-sm text-gray-200">Request Advance</div>
                      <div className="text-xs text-gray-500">Ask for partial payment</div>
                    </div>
                  </div>
                  <ArrowLeft className="w-4 h-4 text-gray-600 rotate-180" />
                </button>

                <button className="w-full bg-[#1a1a1a] hover:bg-[#222] border border-[#2a2a2a] rounded-2xl p-4 flex items-center justify-between transition-colors">
                  <div className="flex items-center">
                    <div className="w-10 h-10 rounded-full bg-blue-500/10 flex items-center justify-center text-blue-500 mr-4">
                      <FileCode className="w-5 h-5" />
                    </div>
                    <div className="text-left">
                      <div className="font-bold text-sm text-gray-200">Attendance Log</div>
                      <div className="text-xs text-gray-500">View your daily records</div>
                    </div>
                  </div>
                  <ArrowLeft className="w-4 h-4 text-gray-600 rotate-180" />
                </button>
              </div>

            </div>

            {/* Bottom Floating Nav */}
            <div className="absolute bottom-6 left-1/2 -translate-x-1/2 w-[85%] bg-[#1a1a1a]/90 backdrop-blur-xl border border-[#333] rounded-3xl py-3 px-6 flex justify-between items-center shadow-2xl z-30">
              <div className="text-amber-500 p-2"><Smartphone className="w-6 h-6" /></div>
              <div className="text-gray-500 hover:text-gray-300 transition-colors p-2"><Database className="w-6 h-6" /></div>
              <div className="text-gray-500 hover:text-gray-300 transition-colors p-2"><ShieldAlert className="w-6 h-6" /></div>
            </div>

          </div>
        )}
      </div>
    </div>
  );
}