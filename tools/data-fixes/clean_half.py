import re

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'r.half' in line and '<td' in line:
        continue
    if '>H</th>' in line or '>Half</th>' in line:
        continue
    new_lines.append(line)

content = "".join(new_lines)
content = content.replace('r.present + r.half > 0', 'r.present > 0')

with open('/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx', 'w') as f:
    f.write(content)
