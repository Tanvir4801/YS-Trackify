import { MessageCircle } from 'lucide-react';
import { siteConfig } from '@/config/siteConfig';

export default function FloatingWhatsApp() {
  return (
    <aside aria-label="Support and Contact Actions">
      <a
        href={siteConfig.links.whatsappDemo}
        target="_blank"
        rel="noopener noreferrer"
        className="fixed bottom-6 right-6 z-40 flex items-center gap-2.5 px-4 py-3 rounded-full bg-[#25D366] hover:bg-[#20BD5A] text-slate-950 font-heading font-bold text-xs sm:text-sm shadow-2xl transition-all duration-300 hover:scale-105 active:scale-95 group focus:outline-none focus:ring-2 focus:ring-[#25D366] focus:ring-offset-2 focus:ring-offset-trackify-bg"
        aria-label="Chat on WhatsApp with Trackify founder"
      >
        <span className="relative flex h-3 w-3">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-slate-900 opacity-75" />
          <span className="relative inline-flex rounded-full h-3 w-3 bg-slate-950" />
        </span>
        <MessageCircle className="w-5 h-5 flex-shrink-0" />
        <span className="hidden sm:inline">WhatsApp Founder</span>
      </a>
    </aside>
  );
}

