import os
import re

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

def convert_to_async(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # If it's importing MOCK_CONTRACTORS, let's swap it to getAllCustomers
    if 'MOCK_CONTRACTORS' in content:
        content = content.replace('MOCK_CONTRACTORS', 'getAllCustomers')
        content = content.replace('import { getAllCustomers', 'import { getAllCustomers') # idempotency hack
        
        # We need to inject useState and useEffect to load the data.
        # Find the component definition
        component_match = re.search(r'export default function (\w+)\((.*?)\) {', content)
        if component_match:
            comp_name = component_match.group(1)
            
            # Simple heuristic: insert state after component def
            state_injection = """
  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);
"""
            # Add useState and useEffect to imports if missing
            if 'useState' not in content:
                content = content.replace("import React", "import React, { useState, useEffect }")
            elif 'useEffect' not in content:
                content = content.replace("useState", "useState, useEffect")

            # Replace the old MOCK_CONTRACTORS array references with allCustomers
            # Because we renamed MOCK_CONTRACTORS to getAllCustomers in the import, 
            # some references might be `getAllCustomers.filter` etc.
            content = content.replace('getAllCustomers.filter', 'allCustomers.filter')
            content = content.replace('getAllCustomers.reduce', 'allCustomers.reduce')
            content = content.replace('getAllCustomers.length', 'allCustomers.length')
            content = content.replace('[...getAllCustomers]', '[...allCustomers]')
            content = content.replace('getAllCustomers.find', 'allCustomers.find')
            content = content.replace('getAllCustomers[0]', 'allCustomers[0]')
            
            # Insert state
            content = content.replace(component_match.group(0), component_match.group(0) + state_injection)
            
            with open(file_path, 'w') as f:
                f.write(content)

for filename in files_to_update:
    path = os.path.join(base_dir, filename)
    if os.path.exists(path):
        convert_to_async(path)

