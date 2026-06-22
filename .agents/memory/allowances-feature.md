---
name: Allowances & Advance feature
description: Daily site allowances (petrol/lunch/breakfast/tea) + per-labour advance deduction wired into attendance records.
---

## Firestore schema
- `attendance/{id}` and `attendance/{contractorId}/dates/{date}/records/{labourId}` both get:
  - `allowances: {petrol, lunch, breakfast, tea}` (nested map)
  - `totalAllowance`, `advance`, `grandTotal`
- `siteAllowances/{date}_{siteId}` — audit doc written whenever allowances are applied
- `advances/{labourId}/entries/{autoId}` — per-advance ledger entry (written by setAdvance)

## Hive field indices
- Attendance: petrol=15, lunch=16, breakfast=17, tea=18, advance=19 (writeByte(20) total)
- SiteModel: defaultPetrol=7, defaultLunch=8, defaultBreakfast=9, defaultTea=10 (writeByte(11) total)

## Key rules
- `totalAllowance = petrol + lunch + breakfast + tea` (computed getter, not stored in Hive)
- `grandTotal = wageAtTime + totalAllowance - advance` (computed getter)
- Allowances (petrol/lunch/breakfast/tea) → "Apply to All" present labours at a site
- Advance → individual per labour only; never batch-applied
- `applyAllowances` filters `_attendanceBox.values` by date + siteId + status==present, then batch-updates both flat and nested Firestore docs

## UI trigger
- `_AllowanceBottomSheet` shown via "Allowances" button in the active-site banner of `attendance_screen.dart`
- Pre-filled from `SiteModel.defaultPetrol/defaultLunch/defaultBreakfast/defaultTea`
- "Skip for today" closes without writing; "Apply to N Labours" calls `AttendanceProvider.applyAllowances`

**Why:** Contractor asked for site-wide daily allowances (petrol/food) added to payroll, plus individual daily advance deductions. Keeping allowances site-wide and advance individual was an explicit design decision.
