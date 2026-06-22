---
name: QR site-session feature
description: Full QR-based site attendance session flow — Flutter model/service/scanner, dashboard site cards, React admin session status + bulk QR ZIP.
---

## Core data model
Firestore collection: `attendanceSessions/{sessionId}`
Fields: supervisorId, supervisorName, siteId, siteName, date, contractorId, startedAt, endedAt (null), status (active|completed|abandoned), markedCount, totalPresent, allowancesApplied.

## Flutter key files
- `lib/models/attendance_session_model.dart` — AttendanceSession + SessionStatus enum
- `lib/services/attendance_session_service.dart` — startSession, endSession, incrementMarkedCount, streamSessionsForToday, streamMyActiveSession, abandonOldSessions, SessionConflictException
- `lib/screens/scanner/session_scanner_screen.dart` — full session QR scanner with tabs (QR+Manual), flash card, remark sheet, 3-step end-session flow (absent confirm → allowances → summary)
- `lib/screens/dashboard_screen.dart` — site session cards section with PENDING/IN PROGRESS/COMPLETE badges; uses SitesProvider + AttendanceSessionService stream

## QR format handled
- Admin format (no expiry): `{"labourId":"...","name":"...","type":"labour_qr","appId":"..."}`
- V2 format (with contractorId + expiresAt): `{"labourId":"...","contractorId":"...","labourName":"...","expiresAt":...}`
- `scanner_service.dart decodeJsonQr` checks `type=='labour_qr'` first (admin path), then falls back to v2 contractorId validation.

## React admin key files
- `Trackify_Admin/src/lib/services/sessions.service.js` — subscribeSessionsForDate, forceEndSession
- `Trackify_Admin/src/pages/Attendance.jsx` — sessions state + sessionMap; site cards show PENDING/IN PROGRESS/COMPLETE badges with animated dot for active
- `Trackify_Admin/src/pages/Labours.jsx` — bulkDownloadQR() uses dynamic import('jszip'), generates QR for selected or all active labours, bundles as ZIP download

## How sessions and scanner connect
Dashboard → tap site card → startSession() → navigate to SessionScannerScreen(session).
Scanner writes attendance with siteId+sessionId stamped on each record, then calls incrementMarkedCount. End session → absent confirm sheet → allowances sheet → endSession() → summary sheet → pop.

**Why:** The site-session model ties attendance records to a specific site+supervisor work session, enabling site-level reporting and preventing duplicate sessions per site per day.
