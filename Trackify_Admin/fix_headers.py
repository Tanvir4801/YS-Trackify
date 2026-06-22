import re

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'r') as f:
    content = f.read()

content = content.replace('>P</th>', ' title="Total Days Present">Days</th>')
content = content.replace('>Present</th>', '>Days Present</th>')
content = content.replace("columns = ['Site', 'Present', 'Half', 'Absent', 'Unique Labours', 'OT Hrs', 'Grand Total'];", "columns = ['Site', 'Days', 'Absent', 'Unique Labours', 'OT Hrs', 'Grand Total'];")

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'w') as f:
    f.write(content)
