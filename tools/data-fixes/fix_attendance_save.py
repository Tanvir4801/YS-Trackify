import re

with open('src/pages/Attendance.jsx', 'r') as f:
    code = f.read()

new_save = """  const handleSave = async () => {
    if (!writeScope) { toast.error('Pick a contractor in the header before saving'); return; }
    if (labours.length === 0) { toast.error('No labours to mark'); return; }

    const changedIds = Object.keys(localChanges);
    if (changedIds.length === 0) {
      toast.error('No changes to save');
      return;
    }

    // Only save labours that have explicit status chosen in this session.
    const dataToSave = changedIds
      .map((rowKey) => {
        const currentRow = rows[rowKey];
        if (!currentRow) return null;
        const labour = labours.find((l) => l.id === currentRow.labourId);
        if (!labour) return null;

        const change = localChanges[rowKey] || {};
        const st = change.status ?? currentRow.status;

        if (!(st === 'present' || st === 'three_quarter' || st === 'half' || st === 'quarter' || st === 'absent')) return null;

        // Keep latest from UI row
        return {
          labourId: currentRow.labourId,
          status: st,
          overtimeHours: Number(currentRow.overtimeHours) || 0,
          remark: currentRow.remark || '',
          wageAtTime: Number(labour.dailyWage) || 0,
          // IMPORTANT: when viewing a specific site, we store siteId in the local change via the dropdown handler.
          siteId: change.siteId ?? currentRow.siteId ?? '',
          recordId: currentRow.recordId,
        };
      })
      .filter(Boolean);"""

code = re.sub(r'  const handleSave = async \(\) => \{[\s\S]*?\.filter\(Boolean\);', new_save, code)

with open('src/pages/Attendance.jsx', 'w') as f:
    f.write(code)
