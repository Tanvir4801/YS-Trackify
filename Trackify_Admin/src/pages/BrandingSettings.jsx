import React, { useState, useEffect } from 'react';
import { useBranding } from '../context/BrandingContext';
import { useAuthStore } from '../store/authStore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '../lib/firebase';
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

export default function BrandingSettings() {
  const { branding, loading, updateBranding } = useBranding();
  const contractorId = useAuthStore((s) => s.userContractorId || s.uid);
  
  const [formData, setFormData] = useState({
    companyName: branding?.companyName || 'Trackify',
    tagline: '',
    address: '',
    phone: '',
    email: '',
    gstNumber: '',
    themeColor: '#F5A623',
    pdfHeaderNote: 'Thank you for your business',
    invoicePrefix: 'INV',
  });
  const [uploading, setUploading] = useState(false);
  const [isDirty, setIsDirty] = useState(false);

  useEffect(() => {
    if (!loading && branding) {
      setFormData({
        companyName: branding.companyName || '',
        tagline: branding.tagline || '',
        address: branding.address || '',
        phone: branding.phone || '',
        email: branding.email || '',
        gstNumber: branding.gstNumber || '',
        themeColor: branding.themeColor || '#F5A623',
        pdfHeaderNote: branding.pdfHeaderNote || 'Thank you for your business',
        invoicePrefix: branding.invoicePrefix || 'INV',
      });
    }
  }, [loading, branding]);

  const handleChange = (e) => {
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
    setIsDirty(true);
  };

  const handleColorChange = (hex) => {
    setFormData(prev => ({ ...prev, themeColor: hex }));
    setIsDirty(true);
    // Live preview by temporarily overriding CSS vars
    const root = document.documentElement;
    root.style.setProperty('--gold', hex);
    root.style.setProperty('--brand-primary', hex);
  };

  const uploadLogo = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 2 * 1024 * 1024) {
      toast.error('Logo must be under 2MB');
      return;
    }
    
    setUploading(true);
    try {
      const safeCompanyName = (formData.companyName || 'Unknown').replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
      const folderName = `${safeCompanyName}_${contractorId}`;
      const logoPath = `branding/${folderName}/logo.png`;
      
      const storageRef = ref(storage, logoPath);
      await uploadBytes(storageRef, file);
      const url = await getDownloadURL(storageRef);
      
      await updateBranding({ 
        logoUrl: url,
        logoStoragePath: logoPath,
      });
      
      toast.success('Logo uploaded successfully');
    } catch (err) {
      console.error(err);
      toast.error('Upload failed');
    } finally {
      setUploading(false);
      // reset input
      e.target.value = '';
    }
  };

  const handleRemoveLogo = async () => {
    try {
      await updateBranding({ 
        logoUrl: null,
        logoStoragePath: null,
      });
      toast.success('Logo removed');
    } catch (err) {
      toast.error('Failed to remove logo');
    }
  };

  const handleSave = async () => {
    try {
      await updateBranding(formData);
      setIsDirty(false);
      toast.success('Branding saved successfully');
    } catch (err) {
      console.error(err);
      toast.error('Failed to save branding');
    }
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Company Branding</h1>
          <p className="text-sm text-text-muted mt-1">
            Customise how your brand appears in the app and documents
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={!isDirty}
          className="px-4 py-2 rounded-lg font-medium transition-colors"
          style={{
            backgroundColor: isDirty ? formData.themeColor : 'var(--bg-elevated)',
            color: isDirty ? '#fff' : 'var(--text-muted)',
            cursor: isDirty ? 'pointer' : 'not-allowed',
          }}
        >
          Save Changes
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Settings */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* Identity Section */}
          <div className="bg-bg-card p-6 rounded-xl border border-border">
            <h2 className="text-lg font-medium text-text-primary mb-4">Basic Information</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">Company Name *</label>
                <input
                  type="text"
                  name="companyName"
                  value={formData.companyName}
                  onChange={handleChange}
                  maxLength={60}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                />
              </div>
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">Tagline</label>
                <input
                  type="text"
                  name="tagline"
                  value={formData.tagline}
                  onChange={handleChange}
                  maxLength={100}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                />
              </div>
              <div className="space-y-1 md:col-span-2">
                <label className="text-sm text-text-secondary">Address</label>
                <textarea
                  name="address"
                  value={formData.address}
                  onChange={handleChange}
                  maxLength={200}
                  rows={2}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold resize-none"
                />
              </div>
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">Phone</label>
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleChange}
                  placeholder="+91"
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                />
              </div>
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">Email</label>
                <input
                  type="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                />
              </div>
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">GST Number</label>
                <input
                  type="text"
                  name="gstNumber"
                  value={formData.gstNumber}
                  onChange={handleChange}
                  placeholder="22AAAAA0000A1Z5"
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold uppercase"
                />
              </div>
            </div>
          </div>

          {/* Logo Section */}
          <div className="bg-bg-card p-6 rounded-xl border border-border">
            <h2 className="text-lg font-medium text-text-primary mb-4">Logo</h2>
            <div className="flex items-start gap-6">
              {branding.logoUrl ? (
                <div className="flex flex-col items-center gap-3">
                  <img
                    src={branding.logoUrl}
                    alt="Company Logo"
                    className="w-[120px] h-[120px] rounded-lg object-contain bg-white"
                  />
                  <div className="flex gap-2">
                    <label className="text-sm text-gold hover:underline cursor-pointer">
                      Change
                      <input type="file" hidden accept="image/png, image/jpeg, image/webp" onChange={uploadLogo} />
                    </label>
                    <span className="text-text-muted">|</span>
                    <button onClick={handleRemoveLogo} className="text-sm text-danger hover:underline">
                      Remove
                    </button>
                  </div>
                </div>
              ) : (
                <label className="w-full border-2 border-dashed border-border-strong hover:border-gold rounded-xl p-8 flex flex-col items-center justify-center cursor-pointer transition-colors bg-bg-input">
                  <input type="file" hidden accept="image/png, image/jpeg, image/webp" onChange={uploadLogo} />
                  {uploading ? (
                    <span className="text-text-muted">Uploading...</span>
                  ) : (
                    <>
                      <svg className="w-8 h-8 text-text-muted mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                      </svg>
                      <span className="text-text-primary font-medium">Click to upload or drag and drop</span>
                      <span className="text-xs text-text-secondary mt-1">PNG, JPG up to 2MB</span>
                      <span className="text-xs text-text-secondary">Recommended: 512×512px square</span>
                    </>
                  )}
                </label>
              )}
            </div>
          </div>

          {/* Theme Color Section */}
          <div className="bg-bg-card p-6 rounded-xl border border-border">
            <h2 className="text-lg font-medium text-text-primary mb-4">Theme Color</h2>
            <div className="flex flex-wrap gap-4 items-center">
              {PRESET_COLORS.map(c => (
                <button
                  key={c.hex}
                  title={c.name}
                  onClick={() => handleColorChange(c.hex)}
                  style={{
                    width: 36, height: 36,
                    borderRadius: '50%',
                    backgroundColor: c.hex,
                    border: formData.themeColor === c.hex ? '2px solid var(--bg-card)' : '2px solid transparent',
                    outline: formData.themeColor === c.hex ? `2px solid ${c.hex}` : 'none',
                    outlineOffset: '2px',
                    cursor: 'pointer',
                  }}
                />
              ))}
              <div className="h-8 w-px bg-border-strong mx-2" />
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  value={formData.themeColor}
                  onChange={(e) => handleColorChange(e.target.value)}
                  className="w-9 h-9 p-0 border-0 rounded cursor-pointer"
                />
                <input
                  type="text"
                  value={formData.themeColor.toUpperCase()}
                  onChange={(e) => handleColorChange(e.target.value)}
                  className="w-24 bg-bg-input border border-border-strong rounded px-2 py-1.5 text-sm text-text-primary focus:outline-none focus:border-gold uppercase"
                />
              </div>
            </div>
          </div>

          {/* Documents Section */}
          <div className="bg-bg-card p-6 rounded-xl border border-border">
            <h2 className="text-lg font-medium text-text-primary mb-4">Documents</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">PDF Footer Note</label>
                <input
                  type="text"
                  name="pdfHeaderNote"
                  value={formData.pdfHeaderNote}
                  onChange={handleChange}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                />
              </div>
              <div className="space-y-1">
                <label className="text-sm text-text-secondary">Invoice Prefix</label>
                <input
                  type="text"
                  name="invoicePrefix"
                  value={formData.invoicePrefix}
                  onChange={handleChange}
                  maxLength={5}
                  className="w-full bg-bg-input border border-border-strong rounded-lg px-4 py-2 text-text-primary focus:outline-none focus:border-gold focus:ring-1 focus:ring-gold uppercase"
                />
                <p className="text-xs text-text-muted">Preview: {formData.invoicePrefix || 'INV'}-001</p>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column - Live Preview */}
        <div className="lg:col-span-1">
          <div className="sticky top-6 bg-white rounded-xl shadow-lg overflow-hidden border border-gray-200">
            {/* PDF Header Preview */}
            <div style={{ backgroundColor: formData.themeColor, height: '6px' }} />
            <div className="p-6">
              <div className="flex justify-between items-start mb-8">
                <div className="flex items-start gap-4">
                  {branding.logoUrl ? (
                    <img src={branding.logoUrl} alt="Logo" className="w-12 h-12 object-contain" />
                  ) : (
                    <div
                      className="w-12 h-12 rounded flex items-center justify-center text-white text-xl font-bold"
                      style={{ backgroundColor: formData.themeColor }}
                    >
                      {(formData.companyName || 'M').charAt(0).toUpperCase()}
                    </div>
                  )}
                  <div>
                    <div className="font-bold text-gray-900 text-lg">
                      {formData.companyName || 'Trackify'}
                    </div>
                    {formData.tagline && (
                      <div className="text-gray-500 text-xs mt-0.5">{formData.tagline}</div>
                    )}
                  </div>
                </div>
                <div className="text-right text-xs text-gray-500 space-y-0.5">
                  {formData.address && <div>{formData.address}</div>}
                  {formData.phone && <div>Ph: {formData.phone}</div>}
                  {formData.gstNumber && <div>GST: {formData.gstNumber.toUpperCase()}</div>}
                </div>
              </div>

              <div style={{ backgroundColor: formData.themeColor, padding: '8px 0', color: 'white', textAlign: 'center', fontWeight: 'bold', fontSize: '12px' }}>
                DOCUMENT TITLE
              </div>
              
              <div className="mt-8 space-y-3">
                <div className="h-4 bg-gray-100 rounded w-full"></div>
                <div className="h-4 bg-gray-100 rounded w-3/4"></div>
                <div className="h-4 bg-gray-100 rounded w-5/6"></div>
              </div>
            </div>
            {/* PDF Footer Preview */}
            <div style={{ backgroundColor: formData.themeColor, padding: '12px', color: 'white', fontSize: '10px' }} className="flex justify-between">
              <span>{formData.pdfHeaderNote}</span>
              <span>{formData.companyName || 'Trackify'}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
