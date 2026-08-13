<div align="center">
  <img src="https://raw.githubusercontent.com/Tanvir4801/YS-Trackify/main/lib/assets/ys.png" alt="Trackify Logo" width="120" />
  
  # 🏗️ Trackify V1.0.0

  **A Premium Full-Stack Workforce & Site Management Platform**

  <p align="center">
    <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB" alt="React" />
    <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
    <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js" />
  </p>
</div>

---

## ✨ Overview

Trackify is a highly scalable, multi-tenant platform built specifically for the construction industry to modernize site operations, labour management, and financial tracking. Designed with a **Firebase-first architecture**, it handles the complexities of remote worksites through seamless offline-first mobile apps while providing contractors with a powerful web-based command center.

> Built to demonstrate production-grade architecture, rigorous data isolation (RBAC), and premium UI/UX design.

---

## 🚀 Ecosystem Apps

Trackify provides tailored experiences for different roles within a construction ecosystem:

### 📱 The Supervisor App (Mobile)
Designed for on-ground execution, built with **Flutter**.
- **Offline-First Sync Engine**: Supervisors can log attendance and expenses deep in remote sites with zero connectivity. Data queues locally and syncs seamlessly once internet is restored.
- **QR Smart Attendance**: Fast, fraud-resistant check-ins using QR codes.
- **Supervisor Notices**: Real-time broadcast system for labour holidays, safety alerts, and project announcements.

### 💻 The Contractor & Admin Dashboard (Web)
The command center for business owners, built with **React (Vite)**.
- **Live Analytics Hub**: Real-time insights into active sites, daily burns, and workforce distribution.
- **Client Ledger & Project Tracking**: A full financial tracking system bridging contractor expenses with client billing.
- **Cost & Profitability Simulator**: Tools to forecast project costs based on current workforce burn rates.

---

## 🎯 Core Features

### 🏢 Multi-Tenant & Role-Based Access
- **Complete Data Isolation**: Powered by stringent Firestore Security Rules, ensuring contractors only ever see their own workforce, sites, and financials.
- **Tiered Access**: Super Admin (Platform Owner), Contractor (Business Owner), and Supervisor (Site Manager) roles with cryptographically secure custom claims.

### 💰 Payroll & Ledger Management
- **Automated Wage Calculation**: Dynamically computes daily, half-day, and overtime wages based on dynamic individual rates.
- **Advance Ledgers**: Tracks cash advances given to laborers and automatically adjusts net payable amounts during final settlements.
- **Export & Reports**: Auto-generation of PDF/Excel reports for compliance and payroll disbursement.

---

## 🛠 Tech Stack & Architecture

### Frontend Layer
- **Mobile**: Flutter (Dart) using `Provider` for state management, `Hive` for NoSQL local caching, and custom offline sync queues.
- **Web**: React.js with Tailwind CSS, delivering a dark-mode premium interface.

### Backend Layer
- **Database**: Firebase Cloud Firestore (NoSQL) with heavy denormalization for read performance.
- **Compute**: Firebase Cloud Functions (Node.js) orchestrating background cron jobs, data aggregations, and webhook processing.
- **Auth & Storage**: Firebase Authentication (Email/Password & OTP) and Cloud Storage for media assets.

### System Flow
1. **Client-Side Syncing**: Advanced offline persistence ensures operations never halt.
2. **Event-Driven Backend**: Cloud functions listen to Firestore writes (e.g., when attendance is marked) and instantly update materialized views (e.g., total site cost), drastically reducing client-side read operations.

---

## 💡 Engineering Highlights

- Designed a robust **NoSQL data model** that handles concurrent offline mutations and real-time syncing without merge conflicts.
- Built a secure, multi-tenant environment using **Firebase Custom Claims** and rigorous **Security Rules**.
- Crafted a **responsive, premium UI** across both Flutter and React, tailored to the unique operational environments of field workers versus office administrators.

---
<div align="center">
  <i>This repository serves as a showcase of my ability to architect and deliver complete, production-ready SaaS platforms.</i>
  <br/><br/>
  <b>Built by Tanvir Patel</b>
</div>
