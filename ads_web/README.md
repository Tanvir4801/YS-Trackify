# Trackify — Construction Workforce Management SaaS Web Platform

A production-quality, custom-designed single-page marketing website for **Trackify**, engineered specifically for contractors, builders, and civil engineering site supervisors.

## 📐 Design Concept: "Live Blueprint"
- **Grid Background**: CSS blueprint grid lines (40px squares, 4% opacity) with dimension lines, corner crop marks, and technical `+` survey markers.
- **Construction-Safety Accents**: Diagonal amber/black hazard stripes under the navbar and between key sections.
- **Technical Typography**:
  - Headings: `Space Grotesk`
  - Body: `Inter`
  - Annotations & Numbers: `JetBrains Mono` (e.g. `// 01 — THE HARSH REALITY`, `SHEET 05 / 12`)
- **Glass Cards**: `backdrop-blur-md bg-white/[0.03] border border-white/[0.08]` with hover translation and active button scaling.
- **Zero External Images**: All visual elements (laptop mockups, rotated smartphone, QR viewfinder with moving scan line, worker ID badges, architectural progress rings) are constructed in 100% pure React, CSS, and SVG.

---

## 🛠 Tech Stack
- **Vite 6** + **React 19** + **TypeScript**
- **Tailwind CSS v3** with custom `trackify` theme extensions
- **Framer Motion** for scroll-triggered reveals, number animations, and modal transitions
- **Lucide React** for clean architectural and construction icons

---

## 📁 Project Structure

```
ads_web/
├── index.html                   # SEO tags, OpenGraph, JSON-LD schema, Google Fonts
├── tailwind.config.ts           # Custom color palette, animations, typography
├── src/
│   ├── config/
│   │   └── siteConfig.ts        # All editable copy, founder info, contact & metrics
│   ├── data/
│   │   ├── navigation.ts        # Nav links mapped to section anchor IDs
│   │   ├── problems.ts          # 3 "Before vs After" reality cards
│   │   ├── features.ts          # 4 showcase tabs + mini-UIs + compact modules
│   │   ├── drawings.ts          # 23 architectural drawing scope definitions
│   │   ├── demo.ts              # Worker roles, daily wage rates, trust items
│   │   ├── howItWorks.ts        # 4 operational workflow steps
│   │   ├── solutions.ts         # 4 persona workflows (Contractor, Builder, etc.)
│   │   └── faq.ts               # 6 technical & operational FAQs
│   ├── hooks/
│   │   ├── useScrollSpy.ts      # Active anchor spy for navigation highlight
│   │   ├── useScrollProgress.ts # Top 2px amber progress indicator
│   │   ├── useCountUp.ts        # Smooth numeric metrics count-up
│   │   └── useReducedMotion.ts  # WCAG accessibility compliance hook
│   ├── utils/
│   │   └── formatCurrency.ts    # Indian Rupee (₹) formatting (lakh/thousand separators)
│   ├── components/
│   │   ├── ui/
│   │   │   ├── SectionHeader.tsx   # Blueprint sheet & technical eyebrow headers
│   │   │   ├── GlassCard.tsx       # Polymorphic glassmorphic panel
│   │   │   ├── Button.tsx          # 4 variants with primary amber CTA
│   │   │   ├── Badge.tsx           # Technical status badges
│   │   │   ├── HazardStripe.tsx    # Safety diagonal stripe bar
│   │   │   ├── ScrollProgress.tsx  # Fixed top progress bar
│   │   │   ├── Modal.tsx           # Accessible focus-trapped dialog
│   │   │   ├── SurveyMarker.tsx    # Blueprint "+" divider line
│   │   │   ├── DemoForm.tsx        # Validated pilot booking form
│   │   │   └── FloatingWhatsApp.tsx# Bottom-right direct founder chat button
│   │   ├── demos/
│   │   │   ├── PayrollCalculator.tsx # Live wage math with advance auto-deduction
│   │   │   ├── OfflineSimulator.tsx  # Phone mockup with SQLite buffer & cloud sync
│   │   │   └── DrawingChecklist.tsx  # 23-plan tracker + client billing statement
│   │   └── sections/
│   │       ├── Navbar.tsx          # Sticky glass nav with mobile slide drawer
│   │       ├── Hero.tsx            # Animated headline underline + dual device mockup
│   │       ├── Problem.tsx         # Site reality vs Trackify fix cards
│   │       ├── Features.tsx        # 4 deep feature tabs with interactive mini-UIs
│   │       ├── InteractiveDemos.tsx# 3 working interactive modules (#plans)
│   │       ├── HowItWorks.tsx      # 4-step timeline + printable QR ID card
│   │       ├── Solutions.tsx       # 4 persona tabs (#solutions)
│   │       ├── Ecosystem.tsx       # Animated SVG system topology diagram
│   │       ├── FounderStory.tsx    # Engineer dossier, metrics count-up (#about)
│   │       ├── FAQ.tsx             # Animated accordion (#faq)
│   │       ├── FinalCTA.tsx        # Lead capture & WhatsApp connection (#demo)
│   │       └── Footer.tsx          # Links, compliance modals (Privacy, Terms, RBAC)
│   ├── App.tsx                  # Main single-page application orchestrator
│   ├── main.tsx                 # React DOM mount
│   └── index.css                # Blueprint grids, scrollbar, hazard stripe utilities
```

---

## 🚀 Running Locally

```bash
# Navigate to the web folder
cd /Users/tanuuux_/Documents/Trackify_Live/Trackify/ads_web

# Start Vite development server
npm run dev

# Or build and test production bundle
npm run build
npm run preview
```

