import React, { createContext, useContext, useState, useEffect } from 'react';
import { doc, onSnapshot, setDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useAuthStore } from '../store/authStore';
import { OFFICIAL_YS_LOGO_DATA_URL } from '../assets/ysLogoBase64';

const BrandingContext = createContext(null);

export const DEFAULT_BRANDING = {
  companyName:    'YS Construction',
  tagline:        'Architecture, Planner, Consultant, Interior Designer',
  address:        'Gokuldham Complex, Opp. Doodh Dairy, ANGALDHARA, Ta. Mahuva, Dist. Surat',
  phone:          '+91 80003 40720, +91 99044 45077',
  email:          'ysconstruction24@gmail.com',
  gstNumber:      '',
  logoUrl:        '/ys_logo.png',
  logoDataUrl:    OFFICIAL_YS_LOGO_DATA_URL,
  logoStoragePath:null,
  themeColor:     '#F5A623',
  themeColorDark: '#D97706',
  themeColorLight:'#FEF3C7',
  pdfHeaderNote:  'Thank you for partnering with YS Construction',
  invoicePrefix:  'INV',
  isSetup:        false,
};

export function BrandingProvider({ children }) {
  // Use activeContractorId, userContractorId, or uid fallback
  const contractorId = useAuthStore((s) => {
    if (s.role === 'super_admin') return s.activeContractorId || s.userContractorId || s.uid;
    if (s.role === 'contractor') return s.userContractorId || s.activeContractorId || s.uid;
    return s.userContractorId || s.uid;
  });
  
  const [branding, setBranding] = useState(() => {
    try {
      const cached = typeof window !== 'undefined' ? localStorage.getItem('trackify_cached_branding') : null;
      if (cached) {
        const parsed = JSON.parse(cached);
        const cachedLogoData = localStorage.getItem('trackify_brand_logo_data_url');
        return {
          ...DEFAULT_BRANDING,
          ...parsed,
          logoDataUrl: parsed.logoDataUrl || cachedLogoData || DEFAULT_BRANDING.logoDataUrl,
        };
      }
    } catch (_) {}
    return DEFAULT_BRANDING;
  });

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!contractorId) {
      setLoading(false);
      return;
    }

    const ref = doc(db, 'contractors', contractorId);
    const unsub = onSnapshot(
      ref,
      (snap) => {
        if (snap.exists()) {
          const data = snap.data();
          const b = data.branding || {};
          const cachedLogoData = typeof window !== 'undefined' ? localStorage.getItem('trackify_brand_logo_data_url') : null;
          const mergedBranding = {
            ...DEFAULT_BRANDING,
            ...b,
            logoUrl: b.logoUrl || DEFAULT_BRANDING.logoUrl,
            logoDataUrl: b.logoDataUrl || cachedLogoData || DEFAULT_BRANDING.logoDataUrl,
            companyName: (b.companyName && b.companyName.toLowerCase() !== 'trackify')
              ? b.companyName
              : ((data.name && data.name.toLowerCase() !== 'trackify') ? data.name : DEFAULT_BRANDING.companyName),
            tagline: b.tagline || DEFAULT_BRANDING.tagline,
            address: b.address || DEFAULT_BRANDING.address,
            phone: b.phone || DEFAULT_BRANDING.phone,
            email: b.email || DEFAULT_BRANDING.email,
          };
          setBranding(mergedBranding);
          try {
            if (mergedBranding.logoDataUrl) {
              localStorage.setItem('trackify_brand_logo_data_url', mergedBranding.logoDataUrl);
            }
            localStorage.setItem('trackify_cached_branding', JSON.stringify(mergedBranding));
          } catch (_) {}
          applyTheme(mergedBranding.themeColor || '#F5A623');
        }
        setLoading(false);
      },
      (err) => {
        console.warn('Could not load branding, using defaults:', err);
        setLoading(false);
      }
    );

    const fallbackTimer = setTimeout(() => {
      setLoading(false);
    }, 3000);

    return () => {
      unsub();
      clearTimeout(fallbackTimer);
    };
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
    const targetCid = contractorId || useAuthStore.getState().userContractorId || useAuthStore.getState().activeContractorId || useAuthStore.getState().uid;
    if (!targetCid) return;
    const ref = doc(db, 'contractors', targetCid);
    const updated = {
      ...branding,
      ...updates,
      updatedAt: new Date(),
      updatedBy: targetCid,
    };
    await setDoc(ref, { branding: updated }, { merge: true });
    setBranding(updated);
    try {
      if (updated.logoDataUrl) {
        localStorage.setItem('trackify_brand_logo_data_url', updated.logoDataUrl);
      }
      localStorage.setItem('trackify_cached_branding', JSON.stringify(updated));
    } catch (_) {}
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
