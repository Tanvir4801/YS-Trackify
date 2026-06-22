import os

files_to_update = [
    'SACustomers.jsx',
    'SADashboard.jsx',
    'SASubscriptions.jsx',
    'SACustomerProfile.jsx',
    'SAGrowth.jsx',
    'SAInsights.jsx',
    'SAChurn.jsx',
    'SAUsageAnalytics.jsx'
]

base_dir = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/superadmin'

def fix_syntax(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Fix the corrupted useState calls
    content = content.replace("useState, useEffect(", "useState(")
    
    # Fix corrupted imports like `import React, { useState, useEffect }, { useMemo }`
    content = content.replace("import React, { useState, useEffect }, {", "import React, { useState, useEffect,")
    content = content.replace("import React, { useState, useEffect, useEffect", "import React, { useState, useEffect")
    content = content.replace("import React, { useState, useEffect } from", "import React, { useState, useEffect } from")

    with open(file_path, 'w') as f:
        f.write(content)

for filename in files_to_update:
    path = os.path.join(base_dir, filename)
    if os.path.exists(path):
        fix_syntax(path)

