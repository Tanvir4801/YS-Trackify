import re

with open('src/pages/Attendance.jsx', 'r') as f:
    code = f.read()

# 1. Update useEffect that populates `rows`
new_use_effect = """  useEffect(() => {
    const next = {};
    labours.forEach((l) => {
      const matchingRecords = records.filter((r) => r.labourId === l.id);
      
      if (matchingRecords.length > 0) {
        matchingRecords.forEach((existing) => {
          // Fallback to labourId if siteId is missing (legacy records)
          const recordKey = existing.siteId ? `${l.id}_${existing.siteId}` : l.id;
          const localChange = localChangesRef.current[recordKey];
          
          if (localChange !== undefined) {
            next[recordKey] = {
              labourId: l.id,
              status: existing.status || 'pending',
              overtimeHours: Number(existing.overtimeHours) || 0,
              remark: existing.remark || existing.notes || '',
              wageAtTime: Number(existing.wageAtTime) || Number(l.dailyWage) || 0,
              shiftFactor: existing.shiftFactor,
              siteId: existing.siteId || '',
              recordId: existing.id,
              petrol: Number(existing.petrol) || 0,
              lunch: Number(existing.lunch) || 0,
              breakfast: Number(existing.breakfast) || 0,
              tea: Number(existing.tea) || 0,
              advance: Number(existing.advance) || 0,
              markedVia: existing.markedVia || '',
              ...localChange,
            };
          } else {
            next[recordKey] = {
              labourId: l.id,
              status: existing.status || 'pending',
              overtimeHours: Number(existing.overtimeHours) || 0,
              remark: existing.remark || existing.notes || '',
              wageAtTime: Number(existing.wageAtTime) || Number(l.dailyWage) || 0,
              shiftFactor: existing.shiftFactor,
              siteId: existing.siteId || '',
              recordId: existing.id,
              petrol: Number(existing.petrol) || 0,
              lunch: Number(existing.lunch) || 0,
              breakfast: Number(existing.breakfast) || 0,
              tea: Number(existing.tea) || 0,
              advance: Number(existing.advance) || 0,
              markedVia: existing.markedVia || '',
            };
          }
        });
      } else {
        const localRow = rows[l.id]; // default key for pending
        if (localRow) {
          next[l.id] = localRow;
        } else {
          next[l.id] = defaultRow(l);
        }
      }
    });
    setRows(next);
  }, [labours, records]);"""

code = re.sub(r'  useEffect\(\(\) => \{\n    const next = \{\};\n    labours\.forEach\(\(l\) => \{[\s\S]*?  \}, \[labours, records, selectedSite\]\);', new_use_effect, code)

# 2. Update updateRow to take rowKey
code = code.replace('const updateRow = (labourId, patch) => {', 'const updateRow = (rowKey, patch) => {')
code = code.replace('setRows((prev) => ({ ...prev, [labourId]: { ...prev[labourId], ...patch } }));', 'setRows((prev) => ({ ...prev, [rowKey]: { ...prev[rowKey], ...patch } }));')
code = code.replace('const currentRow = rows[labourId];', 'const currentRow = rows[rowKey];')
code = code.replace('changes[labourId] = {', 'changes[rowKey] = {')

# 3. Update markAll to use row keys
# wait, markAll iterates labours.forEach(l)
new_mark_all = """  const markAll = (status) => {
    const next = { ...rows };
    const changes = { ...localChanges };

    Object.keys(next).forEach((rowKey) => {
      const curr = next[rowKey];
      const l = labours.find(lab => lab.id === curr.labourId);
      if (!l) return;
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) return;
      if (selectedSite && curr.siteId && curr.siteId !== selectedSite) return;
      
      next[rowKey] = { ...curr, status };
      if (status === 'present' || status === 'three_quarter' || status === 'half' || status === 'quarter' || status === 'absent') {
        changes[rowKey] = { status };
      }
    });

    setRows(next);
    setLocalChanges(changes);
    toast.success(`All filtered rows marked ${status}`);
  };"""
code = re.sub(r'  const markAll = \(status\) => \{[\s\S]*?  \};', new_mark_all, code)

# 4. Update the render loop
# Wait, let's create a displayRows array
# I will write a new displayRows useMemo above summaryCounts
display_rows_hook = """  const displayRows = useMemo(() => {
    return Object.entries(rows).map(([rowKey, row]) => {
      const l = labours.find(lab => lab.id === row.labourId);
      return { rowKey, row, l };
    }).filter(({ row, l }) => {
      if (!l) return false;
      if (search && !l.name?.toLowerCase().includes(search.toLowerCase()) && !l.phone?.includes(search)) return false;
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) return false;
      if (statusFilter !== 'all' && row.status !== statusFilter) return false;
      // Filter by selected site if specified
      if (selectedSite) {
         // If a site is selected, only show records matching that site, OR pending workers
         if (row.siteId && row.siteId !== selectedSite) return false;
         // If they have a siteId from another record, but this is the pending row... wait
         // If we are filtering by site, we probably only want to see them if they are pending or have this site
      }
      return true;
    }).sort(({ l: a }, { l: b }) => (a.name || '').localeCompare(b.name || ''));
  }, [rows, labours, search, supervisorFilter, statusFilter, selectedSite]);"""

# Replace `filtered` with `displayRows`
code = re.sub(r'  const filtered = useMemo\(\(\) => \{[\s\S]*?  \}, \[labours, rows, search, supervisorFilter, statusFilter, selectedSite\]\);', display_rows_hook, code)

# Find where `filtered.map` is
code = code.replace('filtered.map((l) => {', 'displayRows.map(({ rowKey, row, l }) => {')
code = code.replace('const row = rows[l.id];', '')
code = code.replace('key={l.id}', 'key={rowKey}')
# Update all `updateRow(l.id` to `updateRow(rowKey` inside the table
code = code.replace('updateRow(l.id', 'updateRow(rowKey')
code = code.replace('setEditingOT(l.id)', 'setEditingOT(rowKey)')
code = code.replace('editingOT === l.id', 'editingOT === rowKey')
code = code.replace('setEditingRemark(l.id)', 'setEditingRemark(rowKey)')
code = code.replace('editingRemark === l.id', 'editingRemark === rowKey')
code = code.replace('handleRemarkSave(l.id)', 'handleRemarkSave(rowKey)')
code = code.replace('setEditingAllowances(l.id)', 'setEditingAllowances(rowKey)')
code = code.replace('editingAllowances === l.id', 'editingAllowances === rowKey')

with open('src/pages/Attendance.jsx', 'w') as f:
    f.write(code)

