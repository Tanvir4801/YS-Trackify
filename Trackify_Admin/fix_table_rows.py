import re

with open('src/pages/Attendance.jsx', 'r') as f:
    code = f.read()

# Replace tableRows signature
code = code.replace('const tableRows = (list) => list.map((l) => {', 'const tableRows = (list) => list.map(({ rowKey, row, l }) => {')

with open('src/pages/Attendance.jsx', 'w') as f:
    f.write(code)

