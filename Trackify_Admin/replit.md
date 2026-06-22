# Trackify — Labour Admin Panel

A React + Firebase admin panel for managing labour, attendance, and payments
across multiple contractors with role-based access. Companion to the YS
Construction Flutter mobile app (Firebase project `ys-construction`).

## Stack

- React 18 + Vite (JavaScript / JSX, no TypeScript)
- Firebase Auth + Firestore (project: `ys-construction`, `asia-south1`)
- Zustand for global auth/contractor state
- TanStack React Query for cached reads (payments, supervisors, users)
- `onSnapshot` for real-time data (labours, attendance)
- TailwindCSS for styling, lucide-react for icons, react-hot-toast for notifications

## Roles & data scope

| Role          | Default page  | Sidebar links                  | Data scope                                  |
| ------------- | ------------- | ------------------------------ | ------------------------------------------- |
| `super_admin` | `/dashboard`  | All pages, contractor switcher | Selected contractor (or "All" → null scope) |
| `contractor`  | `/dashboard`  | All pages                      | Their own UID                               |
| `supervisor`  | `/attendance` | Attendance, My Labours         | Their own UID (read-only labours)           |

Routes `/dashboard`, `/payments`, `/users`, `/reports` are blocked for
supervisor and redirect to `/attendance`.

The `useScopeId()` hook returns the value used to scope queries:
`super_admin` → selected contractor id (or null), others → their UID.

## Firestore data model (matches Flutter app)

- `contractors/{contractorId}` — `name, email, phone, plan, isActive, createdAt`
- `users/{uid}` — `uid, name, email, phone, role, contractorId, supervisorId, labourId, isActive, ...` (doc ID = Firebase Auth UID)
- `labours/{labourId}` — `id, name, phone, skill, dailyWage, overtimeWagePerHour, defaultOvertimeHours, supervisorId, contractorId, supervisorRef ('users/{uid}' string), isActive, isSynced, syncedAt, createdAt, updatedAt`
- `attendance/{attendanceId}` — **flat collection**: `id, labourId, supervisorId, contractorId, date ('YYYY-MM-DD'), status ('present'|'absent'|'half'), overtimeHours, isSynced, syncedAt, updatedAt`
- `payments/{paymentId}` — `id, labourId, supervisorId, contractorId, type ('salary'|'advance'|'overtime_bonus'), amount, date (Timestamp), notes, isSynced, updatedAt`

### Important conventions

- Flutter mirrors the same supervisor UID into BOTH `supervisorId` and
  `contractorId` on labours/attendance/payments. Services therefore query both
  fields with the scope id and dedupe by document id.
- `payments.date` is a Firestore **Timestamp** (not a string).
- `labours.supervisorRef` is stored as a path string `'users/{uid}'`, not a
  `DocumentReference`.
- Attendance has no `hoursWorked / checkIn / checkOut` — only `status` and
  `overtimeHours`.

## Project structure

```
src/
├── App.jsx                      # Routing + onAuthStateChanged bootstrap
├── main.jsx                     # Router, QueryClient, Toaster providers
├── lib/
│   ├── firebase.js              # Firebase init + secondary auth for user creation
│   ├── utils.js                 # cn, toDateKey/toDateKeySafe, formatCurrency, formatDate, exportCSV
│   └── services/                # All Firestore I/O lives here
│       ├── users.service.js
│       ├── labours.service.js
│       ├── attendance.service.js
│       └── payments.service.js
├── store/
│   └── authStore.js             # Zustand store + useScopeId() helper
├── hooks/
│   ├── useLabours.js            # onSnapshot real-time, scoped
│   ├── useAttendance.js         # onSnapshot real-time, scoped
│   ├── usePayments.js           # React Query
│   ├── useSupervisors.js        # React Query
│   └── useUsers.js              # React Query
├── components/
│   ├── layout/{AppLayout,Sidebar,Header,ProtectedRoute}.jsx
│   ├── shared/{StatusBadge,LoadingSpinner,EmptyState,RoleRoute}.jsx
│   └── ui/                      # Pre-existing primitives
└── pages/
    ├── Login.jsx
    ├── Dashboard.jsx            # Today: present/absent/half + OT, monthly payments, recent payments
    ├── Labours.jsx              # CRUD + Daily Wage / OT Rate / Default OT Hrs / supervisor
    ├── Attendance.jsx           # Status (present/absent/half) + editable OT hours
    ├── Payments.jsx             # Type filter (salary/advance/OT bonus), Timestamp dates
    ├── Users.jsx                # Create supervisors/contractors via secondary auth
    └── Reports.jsx              # Monthly salary report (gross + OT − advances)
```

## Auth flow (`src/App.jsx`)

1. `onAuthStateChanged` fires
2. Fetch `users/{uid}` profile
3. If active, push role/name/contractorId into the auth store
4. If `super_admin`: load `contractors` collection for the picker, default to
   "All" (`activeContractorId = null`)
5. Otherwise resolve their fixed contractor's name
6. Redirect: `supervisor → /attendance`, others → `/dashboard`

## User creation (Users page)

Uses a secondary Firebase app (`getSecondaryAuth()` in `lib/firebase.js`) so
that creating a new account does NOT sign out the currently logged-in admin.
Then writes the Firestore profile via `setDoc(users/{newUid}, ...)`.

## Required Firestore indexes

Composite queries Firestore will ask you to create the first time they run:

- `labours`: `isActive` ASC + `supervisorId` ASC
- `labours`: `isActive` ASC + `contractorId` ASC
- `attendance`: `date` ASC + `supervisorId` ASC
- `attendance`: `date` ASC + `contractorId` ASC
- `attendance`: `date` ASC + `supervisorId` ASC + `labourId` ASC (range reports)
- `payments`: `supervisorId` ASC + `date` DESC (and variants with `type`/`labourId`)
- `users`: `contractorId` ASC + `role` ASC + `name` ASC
- `users`: `role` ASC + `isActive` ASC + `name` ASC

When Firestore prints a "Create index" link in the browser console, click it.

## Environment

Replit secrets (set via the secret store, NOT a checked-in `.env`):

```
VITE_FIREBASE_API_KEY
VITE_FIREBASE_AUTH_DOMAIN
VITE_FIREBASE_PROJECT_ID
VITE_FIREBASE_STORAGE_BUCKET
VITE_FIREBASE_MESSAGING_SENDER_ID
VITE_FIREBASE_APP_ID
```

Vite requires the `VITE_` prefix to expose vars to the client. Firebase web
config keys are public-by-design; security is enforced by `firestore.rules`.

## Workflow

`Start application` → `npm run dev` on port 5000 (Vite, `host: 0.0.0.0`,
`allowedHosts: true`).
