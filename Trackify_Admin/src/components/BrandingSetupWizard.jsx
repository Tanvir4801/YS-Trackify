import React, { useState } from 'react';
import { useBranding } from '../context/BrandingContext';
import { useAuthStore } from '../store/authStore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '../lib/firebase';
import { Compass } from 'lucide-react';
import toast from 'react-hot-toast';

const PRESET_COLORS = [
  { hex: '#F5A623', name: 'Construction Gold' },
  { hex: '#1D4ED8', name: 'Royal Blue' },
  { hex: '#16A34A', name: 'Forest Green' },
  { hex: '#DC2626', name: 'Site Red' },
  { hex: '#7C3AED', name: 'Deep Purple' },
  { hex: '#0891B2', name: 'Steel Blue' },
  { hex: '#374151', name: 'Concrete Grey' },
  { hex: '#92400E', name: 'Dark Amber' },
];

export default function BrandingSetupWizard({ onComplete }) {
  const { branding, updateBranding } = useBranding();
  const contractorId = useAuthStore((s) => s.userContractorId || s.uid);
  
  const [step, setStep] = useState(1);
  const [companyName, setCompanyName] = useState(branding?.companyName || '');
  const [logoUrl, setLogoUrl] = useState(branding?.logoUrl || null);
  const [logoStoragePath, setLogoStoragePath] = useState(branding?.logoStoragePath || null);
  const [themeColor, setThemeColor] = useState(branding?.themeColor || '#F5A623');
  const [uploading, setUploading] = useState(false);

  const handleNext = () => setStep(s => s + 1);
  const handleBack = () => setStep(s => s - 1);

  const handleUploadLogo = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 2 * 1024 * 1024) {
      toast.error('Logo must be under 2MB');
      return;
    }
    
    setUploading(true);
    try {
      const safeCompanyName = (companyName || 'Unknown').replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
      const folderName = `${safeCompanyName}_${contractorId}`;
      const logoPath = `branding/${folderName}/logo.png`;
      
      const storageRef = ref(storage, logoPath);
      await uploadBytes(storageRef, file);
      const url = await getDownloadURL(storageRef);
      setLogoUrl(url);
      setLogoStoragePath(logoPath);
      toast.success('Logo uploaded');
    } catch (err) {
      console.error(err);
      toast.error('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const handleFinish = async () => {
    try {
      await updateBranding({
        companyName: companyName || 'Trackify',
        logoUrl,
        logoStoragePath,
        themeColor,
        isSetup: true,
      });
      if (onComplete) onComplete();
    } catch (err) {
      console.error(err);
      toast.error('Failed to complete setup');
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-bg-primary flex items-center justify-center p-6 overflow-y-auto">
      <div className="max-w-xl w-full bg-[#1A1D24] rounded-2xl border border-gray-800 p-8 shadow-2xl relative">
        <div className="flex justify-between items-center mb-8">
          <div className="flex gap-2">
            {[1, 2, 3, 4].map(i => (
              <div 
                key={i} 
                className={`h-2 w-12 rounded-full transition-colors ${i <= step ? 'bg-brand-primary' : 'bg-gray-700'}`}
                style={{ backgroundColor: i <= step ? themeColor : '#374151' }}
              />
            ))}
          </div>
          <span className="text-gray-500 text-sm font-medium">Step {step} of 4</span>
        </div>

        {step === 1 && (
          <div className="space-y-6">
            <h1 className="text-3xl font-bold text-gray-100">What's your company name?</h1>
            <p className="text-gray-400">This appears on all your reports, invoices, and the app.</p>
            <input
              type="text"
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              placeholder="e.g. YS Construction"
              autoFocus
              className="w-full bg-[#2A2D35] border border-gray-700 rounded-xl px-5 py-4 text-xl text-gray-100 focus:outline-none transition-colors"
              style={{ borderBottom: `2px solid ${companyName ? themeColor : 'transparent'}` }}
            />
            <div className="pt-4 flex justify-end">
              <button 
                onClick={handleNext} 
                disabled={!companyName.trim()}
                className="px-6 py-3 rounded-xl font-medium text-white transition-opacity disabled:opacity-50"
                style={{ backgroundColor: themeColor }}
              >
                Continue
              </button>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-6">
            <h1 className="text-3xl font-bold text-gray-100">Upload your logo</h1>
            <p className="text-gray-400">Add a professional touch to your documents.</p>
            
            <div className="py-6 flex justify-center">
              {logoUrl ? (
                <div className="flex flex-col items-center gap-4">
                  <img src={logoUrl} alt="Logo" className="w-32 h-32 rounded-xl object-contain bg-white" />
                  <button onClick={() => setLogoUrl(null)} className="text-red-500 text-sm hover:underline">Remove</button>
                </div>
              ) : (
                <label className="w-full max-w-sm border-2 border-dashed border-gray-700 hover:border-gray-500 rounded-2xl p-10 flex flex-col items-center justify-center cursor-pointer transition-colors bg-[#2A2D35]">
                  <input type="file" hidden accept="image/png, image/jpeg, image/webp" onChange={handleUploadLogo} />
                  {uploading ? (
                    <span className="text-gray-400">Uploading...</span>
                  ) : (
                    <>
                      <div className="w-12 h-12 bg-gray-800 rounded-full flex items-center justify-center mb-4 text-gray-400">
                        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                        </svg>
                      </div>
                      <span className="text-gray-300 font-medium text-center">Click to upload</span>
                      <span className="text-xs text-gray-500 mt-2">PNG or JPG</span>
                    </>
                  )}
                </label>
              )}
            </div>

            <div className="pt-4 flex justify-between items-center">
              <button onClick={handleBack} className="text-gray-400 hover:text-white px-4 py-2">Back</button>
              <div className="flex gap-4 items-center">
                {!logoUrl && <button onClick={handleNext} className="text-gray-400 hover:text-white text-sm px-2">Skip for now</button>}
                <button 
                  onClick={handleNext}
                  className="px-6 py-3 rounded-xl font-medium text-white"
                  style={{ backgroundColor: themeColor }}
                >
                  Continue
                </button>
              </div>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-6">
            <h1 className="text-3xl font-bold text-gray-100">Pick your brand color</h1>
            <p className="text-gray-400">This colors your entire dashboard and mobile app.</p>
            
            <div className="grid grid-cols-4 gap-4 py-4">
              {PRESET_COLORS.map(c => (
                <button
                  key={c.hex}
                  onClick={() => setThemeColor(c.hex)}
                  className="h-16 rounded-xl transition-transform hover:scale-105 flex items-center justify-center"
                  style={{ 
                    backgroundColor: c.hex,
                    border: themeColor === c.hex ? '3px solid white' : 'none',
                  }}
                >
                  {themeColor === c.hex && (
                    <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  )}
                </button>
              ))}
            </div>

            <div className="bg-[#2A2D35] p-4 rounded-xl border border-gray-700 flex items-center gap-4">
              <input
                type="color"
                value={themeColor}
                onChange={(e) => setThemeColor(e.target.value)}
                className="w-10 h-10 p-0 border-0 rounded cursor-pointer"
              />
              <div>
                <p className="text-sm text-gray-300 font-medium">Custom Color</p>
                <p className="text-xs text-gray-500 uppercase">{themeColor}</p>
              </div>
            </div>

            <div className="pt-4 flex justify-between items-center">
              <button onClick={handleBack} className="text-gray-400 hover:text-white px-4 py-2">Back</button>
              <button 
                onClick={handleNext}
                className="px-6 py-3 rounded-xl font-medium text-white"
                style={{ backgroundColor: themeColor }}
              >
                Continue
              </button>
            </div>
          </div>
        )}

        {step === 4 && (
          <div className="space-y-8">
            <div className="text-center">
              <div 
                className="w-20 h-20 mx-auto rounded-full flex items-center justify-center mb-6 shadow-[0_0_30px_rgba(0,0,0,0.3)]"
                style={{ backgroundColor: themeColor }}
              >
                <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h1 className="text-3xl font-bold text-gray-100">You're all set!</h1>
              <p className="text-gray-400 mt-2">Your workspace is now branded.</p>
            </div>

            {/* Preview Sidebar Area */}
            <div className="bg-[#2A2D35] p-6 rounded-2xl border border-gray-700 mx-auto max-w-xs relative overflow-hidden">
              <div className="flex items-center gap-3">
                {logoUrl ? (
                  <img src={logoUrl} alt="Logo" className="w-10 h-10 rounded-xl bg-white object-contain" />
                ) : (
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center shadow-lg" style={{ backgroundColor: themeColor + '20', border: `1px solid ${themeColor}40` }}>
                    <Compass className="w-5 h-5" style={{ color: themeColor }} />
                  </div>
                )}
                <div>
                  <div className="text-[14px] font-semibold text-white tracking-wide truncate w-40">
                    {companyName.toUpperCase()}
                  </div>
                  <div className="text-[11px] text-gray-400">v2.0</div>
                </div>
              </div>
            </div>

            <div className="pt-4 flex justify-between items-center">
              <button onClick={handleBack} className="text-gray-400 hover:text-white px-4 py-2">Back</button>
              <button 
                onClick={handleFinish}
                className="px-8 py-3 rounded-xl font-bold text-white shadow-lg transition-transform hover:scale-105"
                style={{ backgroundColor: themeColor }}
              >
                Go to Dashboard
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
