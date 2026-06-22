import React, { createContext, useContext, useState, useEffect } from 'react';
import { doc, onSnapshot, updateDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useAuthStore } from '../store/authStore';

const BrandingContext = createContext(null);

export const DEFAULT_BRANDING = {
  companyName:    'Trackify',
  tagline:        'v2.0',
  address:        '',
  phone:          '',
  email:          '',
  gstNumber:      '',
  logoUrl:        null,
  logoStoragePath:null,
  themeColor:     '#F5A623',
  themeColorDark: '#D97706',
  themeColorLight:'#FEF3C7',
  pdfHeaderNote:  'Thank you for your business',
  invoicePrefix:  'INV',
  isSetup:        false,
};

export function BrandingProvider({ children }) {
  // We'll use the userContractorId (for contractor users) or activeContractorId (for super_admins viewing a specific contractor)
  // useScopeId returns the appropriate contractor ID based on role
  const contractorId = useAuthStore((s) => {
    if (s.role === 'super_admin') return s.activeContractorId;
    if (s.role === 'contractor') return s.userContractorId || s.activeContractorId || s.uid;
    return s.userContractorId || s.uid; // fallback
  });
  
  const [branding, setBranding] = useState(DEFAULT_BRANDING);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!contractorId) {
      setLoading(false);
      return;
    }

    const ref = doc(db, 'contractors', contractorId);
    const unsub = onSnapshot(ref, (snap) => {
      if (snap.exists()) {
        const data = snap.data();
        const b = data.branding || {};
        const mergedBranding = {
          ...DEFAULT_BRANDING,
          ...b,
          companyName: b.companyName || data.name || DEFAULT_BRANDING.companyName,
        };
        setBranding(mergedBranding);
        applyTheme(mergedBranding.themeColor || '#F5A623');
      }
      setLoading(false);
    });

    return () => unsub();
  }, [contractorId]);

  const applyTheme = (hex) => {
    const root = document.documentElement;
    root.style.setProperty('--gold', hex);
    root.style.setProperty('--gold-dark', darkenHex(hex, 20));
    root.style.setProperty('--gold-light', lightenHex(hex, 40));
    root.style.setProperty('--gold-bg', hex + '1A');
    root.style.setProperty('--gold-border', hex + '40');
    
    // Also set generic brand vars in case they are used
    root.style.setProperty('--brand-primary', hex);
    root.style.setProperty('--brand-dark', darkenHex(hex, 20));
    root.style.setProperty('--brand-light', lightenHex(hex, 40));
    root.style.setProperty('--brand-bg', hex + '1A');
  };

  const updateBranding = async (updates) => {
    if (!contractorId) return;
    const ref = doc(db, 'contractors', contractorId);
    await updateDoc(ref, {
      branding: {
        ...branding,
        ...updates,
        updatedAt: new Date(),
        updatedBy: contractorId,
      }
    });
  };

  return (
    <BrandingContext.Provider value={{
      branding, loading, updateBranding
    }}>
      {children}
    </BrandingContext.Provider>
  );
}

export const useBranding = () => useContext(BrandingContext);

// Color utilities
function darkenHex(hex, pct) {
  const num = parseInt(hex.replace('#',''), 16);
  const r = Math.max(0,(num>>16)-pct*2.55|0);
  const g = Math.max(0,(num>>8&0xff)-pct*2.55|0);
  const b = Math.max(0,(num&0xff)-pct*2.55|0);
  return '#'+(r<<16|g<<8|b).toString(16).padStart(6,'0');
}
function lightenHex(hex, pct) {
  const num = parseInt(hex.replace('#',''), 16);
  const r = Math.min(255,(num>>16)+pct*2.55|0);
  const g = Math.min(255,(num>>8&0xff)+pct*2.55|0);
  const b = Math.min(255,(num&0xff)+pct*2.55|0);
  return '#'+(r<<16|g<<8|b).toString(16).padStart(6,'0');
}
