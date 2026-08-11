import re

with open('src/pages/Attendance.jsx', 'r') as f:
    code = f.read()

# Replace useMemo for pendingLabours and alreadyMarked
new_memo = """  const { pendingLabours, alreadyMarked } = useMemo(() => {
    const selected = selectedSite;
    const pending = [];
    const marked = [];

    // displayRows is the list of { rowKey, row, l } we injected earlier
    displayRows.forEach(({ rowKey, row, l }) => {
      // row.status is the source of truth for if it's marked or pending
      if (row.status === 'pending') {
         // if it's pending, we show it in pending
         pending.push({ rowKey, row, l });
      } else {
         marked.push({ rowKey, row, l });
      }
    });

    return {
      pendingLabours: pending,
      alreadyMarked: marked,
    };
  }, [displayRows]);"""

code = re.sub(r'  const \{ pendingLabours, alreadyMarked \} = useMemo\(\(\) => \{[\s\S]*?  \}, \[filtered, records, selectedSite, statusFilter, rows\]\);', new_memo, code)

# Update rendering of pendingLabours
code = code.replace('pendingLabours.map((l) => {', 'pendingLabours.map(({ rowKey, row, l }) => {')
# Update rendering of alreadyMarked
code = code.replace('alreadyMarked.map((l) => {', 'alreadyMarked.map(({ rowKey, row, l }) => {')

# Remove duplicate `const row = rows[l.id]` inside the map
code = code.replace('const row = rows[l.id];', '')
code = code.replace('const row = rows[l.id] || {};', '')

# Replace `key={l.id}` with `key={rowKey}` in pending and marked loops
# We have to be careful with regex
code = re.sub(r'pendingLabours\.map\(\(\{ rowKey, row, l \}\) => \{\n\s*const isSaving[\s\S]*?key=\{l\.id\}', lambda m: m.group(0).replace('key={l.id}', 'key={rowKey}'), code)
code = re.sub(r'alreadyMarked\.map\(\(\{ rowKey, row, l \}\) => \{\n\s*const isSaving[\s\S]*?key=\{l\.id\}', lambda m: m.group(0).replace('key={l.id}', 'key={rowKey}'), code)

with open('src/pages/Attendance.jsx', 'w') as f:
    f.write(code)

