import re

with open('src/pages/Attendance.jsx', 'r') as f:
    code = f.read()

# For pendingLabours mapping loop:
code = re.sub(r'pendingLabours\.map\(\(\{ rowKey, row, l \}\) => \{([\s\S]*?)\} // end pending', lambda m: m.group(0).replace('l.id', 'rowKey'), code)

# wait, how to safely replace only inside the pending and alreadyMarked maps?
# Since we replaced the `filtered.map((l) => {` and `alreadyMarked.map((l) => {`
# let's just do a blanket replacement in the render functions:
# In React render:
# onClick={() => clickStatus(l.id)} -> onClick={() => clickStatus(rowKey)}
code = code.replace('clickStatus(l.id)', 'clickStatus(rowKey)')
code = code.replace('handleMarkAsPending(l.id)', 'handleMarkAsPending(rowKey)')
code = code.replace('openAllowanceEdit(l.id)', 'openAllowanceEdit(rowKey)')
code = code.replace('const row = rows[l.id] || defaultRow(l);', '')
code = code.replace('const labourRecords = records.filter(r => r.labourId === l.id && r.status !== \'pending\');', 'const labourRecords = records.filter(r => r.labourId === l.id && r.status !== \'pending\');')

with open('src/pages/Attendance.jsx', 'w') as f:
    f.write(code)
