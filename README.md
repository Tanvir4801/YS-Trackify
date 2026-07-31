# 🏗️ Trackify

Trackify is a full-stack workforce and site management platform tailored for the construction industry. I built this project to demonstrate my ability to architect, develop, and deploy a complex, multi-tenant system using a modern tech stack. 

The platform consists of a **Flutter-based mobile app** designed for on-site supervisors (with offline-first capabilities) and a **React-based Admin Dashboard** for contractors to manage data, generate reports, and oversee multiple sites. Everything is powered by **Firebase** for real-time synchronization, secure authentication, and scalable data storage.

---

## 🚀 Key Features

### 1. Smart Attendance System
- **Offline-First Capabilities**: Supervisors can mark attendance even in remote sites without internet access. The local database queues updates and syncs with Firestore once the connection is restored.
- **Session-Based Tracking**: Support for half-days, full-days, and overtime tracking.

### 2. Payroll & Payments
- **Automated Wage Calculation**: Dynamically computes wages based on attendance records and individual labour rates.
- **Advances & Ledgers**: Tracks cash advances given to labourers and adjusts the net payable amount at the end of the month.
- **Export & Reporting**: Auto-generates Excel and PDF reports for payment disbursements.

### 3. Multi-Tenant Security & Role-Based Access (RBAC)
- **Three-Tier Architecture**: 
  - **Super Admin**: Oversees the entire platform.
  - **Contractor**: Manages their specific sites, labours, and supervisors (isolated via Firebase Security Rules).
  - **Supervisor**: Limited access to assigned sites and daily operations.
- **Secure Data Isolation**: Rigorous Firestore rules ensure that contractors can only access their own data.

### 4. Admin Web Dashboard
- **Real-Time Analytics**: Built with React, providing contractors with live insights, cost analysis, and site expense tracking.
- **Centralized Management**: Manage sites, user roles, base wages, and view detailed monthly reports seamlessly.

---

## 🛠 Tech Stack

### Mobile App (On-Site Supervisors)
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Local Database**: Built-in syncing engine for offline support.

### Admin Dashboard (Contractors & Admins)
- **Framework**: React.js
- **Routing**: React Router
- **Styling**: Tailwind CSS / Custom CSS

### Backend & Infrastructure
- **Database**: Firebase Cloud Firestore (NoSQL)
- **Authentication**: Firebase Auth (Email/Password, Role-based custom claims)
- **Cloud Functions**: Firebase Cloud Functions (Node.js) for backend cron jobs, triggers, and secure data aggregation.
- **Storage**: Firebase Cloud Storage for profile pictures and site media.

---

## 📐 Architecture Overview

1. **Client-Side Syncing**: The Flutter mobile app uses Firestore's offline persistence and custom caching mechanisms. This ensures that attendance and site logs can be recorded smoothly even when cellular reception is spotty.
2. **Data Modeling**: The database is structured to support multi-tenancy. Collections like `users`, `labours`, `sites`, and `attendance` are tied together using robust foreign keys (`contractorId`, `supervisorId`) to maintain data integrity.
3. **Event-Driven Backend**: Firebase Cloud Functions listen to Firestore writes to automatically update materialized views, such as aggregated monthly costs, reducing the query load on the client side.

---

## 💡 What I Learned

Building Trackify allowed me to dive deep into:
- Designing a robust **NoSQL data model** that handles offline mutations and real-time syncing without conflicts.
- Implementing **Firebase Security Rules** to ensure strict multi-tenant data isolation.
- Crafting a **responsive and intuitive UI** in both Flutter (mobile) and React (web) to cater to two vastly different user bases (field workers vs. office administrators).
- Handling **state management** elegantly across complex forms and real-time streams.

---

*This project is part of my portfolio. Feel free to explore the codebase to see my coding style, architectural decisions, and best practices.*
