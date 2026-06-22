import re

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'r') as f:
    content = f.read()

# Helper
helper = """function dateRangeBounds(from, to) { return { start: from, end: to }; }

function getPresentDays(recs) {
  return recs.reduce((s, r) => {
    if (r.status === 'absent' || r.status === 'pending') return s;
    const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
    return s + factor;
  }, 0);
}
"""
content = content.replace('function dateRangeBounds(from, to) { return { start: from, end: to }; }', helper)

# 1. Monthly
content = content.replace("""          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;""", """          const present = getPresentDays(recs);
          const half    = 0; // Deprecated""")

# 2. Attendance
# We already replaced one instance above, let's just do regex for the remaining.
content = re.sub(r'const present = recs\.filter\(\(r\) => r\.status === \'present\'\)\.length;\s*const half\s*= recs\.filter\(\(r\) => r\.status === \'half\'\)\.length;', 
                 r'const present = getPresentDays(recs);\n          const half    = 0;', 
                 content)

# Update rate calculation in attendance and productivity
content = content.replace('const rate    = totalDaysInRange > 0 ? Math.round(((present + half * 0.5) / totalDaysInRange) * 100) : 0;', 
                          'const rate    = totalDaysInRange > 0 ? Math.round((present / totalDaysInRange) * 100) : 0;')
content = content.replace('const rate    = totalDays > 0 ? Math.round(((present + half * 0.5) / totalDays) * 100) : 0;', 
                          'const rate    = totalDays > 0 ? Math.round((present / totalDays) * 100) : 0;')
content = content.replace('const totalDays = present + half * 0.5;', 'const totalDays = present;')

# 3. Overall temp labour map
content = content.replace("""          if (t.attendanceUnit >= 1.0) row.present += 1;
          else if (t.attendanceUnit > 0) row.half += 1;""", """          row.present += (t.attendanceUnit || 0);""")
          
# CSV Exports
content = content.replace("""Rows: r.present, Half: r.half""", """Days: r.present""")
# Let's just fix the CSV strings manually:
content = content.replace("'OT Rate': r.otRate, Present: r.present, Half: r.half, Absent: r.absent, 'OT Hours'", 
                          "'OT Rate': r.otRate, 'Days Present': r.present, Absent: r.absent, 'OT Hours'")
content = content.replace("Name: r.name, Present: r.present, Half: r.half, Absent: r.absent, 'Attendance %'", 
                          "Name: r.name, 'Days Present': r.present, Absent: r.absent, 'Attendance %'")
content = content.replace("Site: r.siteName, Present: r.present, Half: r.half, Absent: r.absent, 'Unique Labours'", 
                          "Site: r.siteName, 'Days Present': r.present, Absent: r.absent, 'Unique Labours'")
content = content.replace("Name: r.name, Type: r.type, Present: r.present, Half: r.half, 'OT Hours'", 
                          "Name: r.name, Type: r.type, 'Days Present': r.present, 'OT Hours'")

# PDF Exports
content = content.replace("['Name', 'Phone', 'Daily Wage', 'Present', 'Half', 'Absent', 'OT Hrs', 'Gross', 'Advances', 'Net']", 
                          "['Name', 'Phone', 'Daily Wage', 'Days', 'Absent', 'OT Hrs', 'Gross', 'Advances', 'Net']")
content = content.replace("[r.name, r.phone, formatCurrency(r.dailyWage), r.present, r.half, r.absent, r.otHours, formatCurrency(r.gross), formatCurrency(r.advances), formatCurrency(r.net)]", 
                          "[r.name, r.phone, formatCurrency(r.dailyWage), r.present, r.absent, r.otHours, formatCurrency(r.gross), formatCurrency(r.advances), formatCurrency(r.net)]")

content = content.replace("['Name', 'Present', 'Half', 'Absent', 'Attendance %']", 
                          "['Name', 'Days', 'Absent', 'Attendance %']")
content = content.replace("[r.name, r.present, r.half, r.absent, `${r.rate}%`]", 
                          "[r.name, r.present, r.absent, `${r.rate}%`]")

content = content.replace("['Site', 'Present', 'Half', 'Absent', 'Unique Labours', 'OT Hrs', 'Grand Total']", 
                          "['Site', 'Days', 'Absent', 'Unique Labours', 'OT Hrs', 'Grand Total']")
content = content.replace("[r.siteName, r.present, r.half, r.absent, r.uniqueLabours, r.otHours, formatCurrency(r.grandTotal || 0)]", 
                          "[r.siteName, r.present, r.absent, r.uniqueLabours, r.otHours, formatCurrency(r.grandTotal || 0)]")

content = content.replace("['Name', 'Type', 'Present', 'Half', 'OT Hrs', 'Gross', 'Net']", 
                          "['Name', 'Type', 'Days', 'OT Hrs', 'Gross', 'Net']")
content = content.replace("[r.name, r.type, r.present, r.half, r.otHours, formatCurrency(r.gross), formatCurrency(r.net)]", 
                          "[r.name, r.type, r.present, r.otHours, formatCurrency(r.gross), formatCurrency(r.net)]")

# HTML Tables
# Monthly
content = content.replace('<th className="px-6 py-4 font-medium text-right text-success">P</th>\\n                    <th className="px-6 py-4 font-medium text-right text-warning">H</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">A</th>', 
                          '<th className="px-6 py-4 font-medium text-right text-success" title="Total Days Present">Days</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>')
content = content.replace('<td className="px-6 py-4 text-right font-mono text-success">{r.present}</td>\\n                      <td className="px-6 py-4 text-right font-mono text-warning">{r.half}</td>\\n                      <td className="px-6 py-4 text-right font-mono text-danger">{r.absent}</td>', 
                          '<td className="px-6 py-4 text-right font-mono text-success">{r.present}</td>\\n                      <td className="px-6 py-4 text-right font-mono text-danger">{r.absent}</td>')
# Attendance
content = content.replace('<th className="px-6 py-4 font-medium text-right text-success">Present</th>\\n                    <th className="px-6 py-4 font-medium text-right text-warning">Half</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>', 
                          '<th className="px-6 py-4 font-medium text-right text-success">Days Present</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>')
content = content.replace('<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>\\n                      <td className="px-6 py-4 text-right font-mono font-medium text-warning">{r.half}</td>\\n                      <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>', 
                          '<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>\\n                      <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>')
# Sitewise
content = content.replace('<th className="px-6 py-4 font-medium text-right text-success">Present</th>\\n                    <th className="px-6 py-4 font-medium text-right text-warning">Half</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>', 
                          '<th className="px-6 py-4 font-medium text-right text-success">Days</th>\\n                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>')
content = content.replace('<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>\\n                        <td className="px-6 py-4 text-right font-mono font-medium text-warning">{r.half}</td>\\n                        <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>', 
                          '<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>\\n                        <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>')
# Overall
content = content.replace('<th className="px-6 py-4 font-medium text-right text-success">P</th>\\n                    <th className="px-6 py-4 font-medium text-right text-warning">H</th>', 
                          '<th className="px-6 py-4 font-medium text-right text-success" title="Total Days Present">Days</th>')
content = content.replace('<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>\\n                      <td className="px-6 py-4 text-right font-mono font-medium text-warning">{r.half}</td>', 
                          '<td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>')

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'w') as f:
    f.write(content)
