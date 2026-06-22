<div align="center">

# 🖥️ Trackify Admin

### The Command Center for Workforce Operations

[![React](https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev)
[![Vite](https://img.shields.io/badge/Vite-8-646CFF?style=flat-square&logo=vite&logoColor=white)](https://vite.dev)
[![TailwindCSS](https://img.shields.io/badge/Tailwind-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)

</div>

---

Trackify Admin is the **React-based admin dashboard** for the Trackify workforce management platform. It provides contractors, super admins, and TrackOps operators with a powerful web interface to manage attendance, payroll, labours, sites, and internal operations.

## 🚀 Quick Start

```bash
npm install
cp .env.example .env    # Add your Firebase config
npm run dev              # → http://localhost:5173
```

## 🏗️ Architecture

```
src/
├── App.jsx              # Root routing & layout
├── components/          # UI components (Shadcn/UI + custom)
├── pages/               # 40+ page components
│   ├── Dashboard.jsx    # Main analytics dashboard
│   ├── trackops/        # 11 internal operations pages
│   ├── superadmin/      # 12 super admin pages
│   └── labs/            # 12 experimental features
├── hooks/               # Custom React hooks
├── store/               # Zustand state management
├── context/             # React context providers
└── lib/                 # Utility functions
```

## 📦 Tech Stack

| Layer | Technology |
|:---|:---|
| **Framework** | React 19 + Vite 8 |
| **Styling** | TailwindCSS 4 + Shadcn/UI |
| **State** | Zustand + React Query |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **Charts** | Recharts |
| **Forms** | React Hook Form + Zod |
| **Icons** | Lucide React |

---

<div align="center">
<sub>Part of the <a href="../README.md">Trackify</a> platform</sub>
</div>
