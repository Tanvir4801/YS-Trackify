import { useState } from 'react';
import ScrollProgress from '@/components/ui/ScrollProgress';
import { Modal } from '@/components/ui/Modal';
import DemoForm from '@/components/ui/DemoForm';
import FloatingWhatsApp from '@/components/ui/FloatingWhatsApp';
import Navbar from '@/components/sections/Navbar';
import Hero from '@/components/sections/Hero';
import Problem from '@/components/sections/Problem';
import Features from '@/components/sections/Features';
import InteractiveDemos from '@/components/sections/InteractiveDemos';
import HowItWorks from '@/components/sections/HowItWorks';
import Solutions from '@/components/sections/Solutions';
import Ecosystem from '@/components/sections/Ecosystem';
import FounderStory from '@/components/sections/FounderStory';
import FAQ from '@/components/sections/FAQ';
import FinalCTA from '@/components/sections/FinalCTA';
import Footer from '@/components/sections/Footer';
import { useScrollSpy } from '@/hooks/useScrollSpy';

const SECTION_IDS = ['features', 'plans', 'how-it-works', 'solutions', 'about', 'demo'];

export default function App() {
  const [isDemoModalOpen, setIsDemoModalOpen] = useState(false);
  const [isDemoSuccess, setIsDemoSuccess] = useState(false);
  const { activeId, scrollToSection } = useScrollSpy(SECTION_IDS);

  const handleOpenDemoModal = () => {
    setIsDemoSuccess(false);
    setIsDemoModalOpen(true);
  };
  const handleCloseDemoModal = () => {
    setIsDemoModalOpen(false);
    setIsDemoSuccess(false);
  };

  return (
    <div className="min-h-screen bg-trackify-bg text-trackify-textMain selection:bg-trackify-amber/30 selection:text-white relative">
      {/* ── Top Fixed Scroll Progress Line ── */}
      <ScrollProgress />

      {/* ── Sticky Live Blueprint Navbar ── */}
      <Navbar
        onDemoClick={handleOpenDemoModal}
        activeSection={activeId}
        onNavigate={scrollToSection}
      />

      {/* ── Main Content Landmark ── */}
      <main id="main-content">
        {/* ── 1. Hero Section ── */}
        <Hero onDemoClick={handleOpenDemoModal} />

        {/* ── 2. The Harsh Reality (Problem Section) ── */}
        <Problem />

        {/* ── 3. Deep Feature Showcase ── */}
        <Features />

        {/* ── 4. Interactive Working Demos (Drawings & Billing) ── */}
        <InteractiveDemos />

        {/* ── 5. Operational Workflow (How It Works) ── */}
        <HowItWorks />

        {/* ── 6. Tailored Solutions by Persona ── */}
        <Solutions />

        {/* ── 7. Ecosystem & Architecture Topology ── */}
        <Ecosystem />

        {/* ── 8. Founder Story & Technical Origin ── */}
        <FounderStory />

        {/* ── 9. Operational & Technical FAQ ── */}
        <FAQ />

        {/* ── 10. Final Call to Action & Dispatch Booking ── */}
        <FinalCTA />
      </main>

      {/* ── 11. Footer & Regulatory Disclosures ── */}
      <Footer />

      {/* ── Floating WhatsApp Support Widget ── */}
      <FloatingWhatsApp />

      {/* ── Global "Book a Free Demo" Modal ── */}
      <Modal
        isOpen={isDemoModalOpen}
        onClose={handleCloseDemoModal}
        title={isDemoSuccess ? undefined : "Schedule Live Platform Demonstration"}
      >
        <div className="pt-1">
          {!isDemoSuccess && (
            <p className="text-xs text-trackify-textMuted mb-5 leading-relaxed">
              Fill out your site requirements below to get instant access to the read-only Trackify Admin Sandbox with 3 active construction sites and 28 workers.
            </p>
          )}
          <DemoForm
            inModal
            onSuccessClose={handleCloseDemoModal}
            onSuccessStateChange={setIsDemoSuccess}
          />
        </div>
      </Modal>
    </div>
  );
}

