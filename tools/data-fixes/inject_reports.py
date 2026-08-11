import re
import os

filepath = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Reports.jsx'

with open(filepath, 'r') as f:
    content = f.read()

# Add useSubscriptionStore import if not there
if 'useSubscriptionStore' not in content:
    content = content.replace("import { useAuthStore, useScopeId } from '../store/authStore';", "import { useAuthStore, useScopeId } from '../store/authStore';\nimport { useSubscriptionStore } from '../store/subscriptionStore';")

# Add featureFlags destructing in Reports component
content = content.replace("const scopeId = useScopeId();", "const scopeId = useScopeId();\n  const { featureFlags } = useSubscriptionStore();")

# Modify handleExport and handleExportPDF logic to just return early or let the UI disable it.
# We will disable the buttons in the UI.
# Find the export buttons
content = content.replace("<button onClick={handleExport} disabled={report.length === 0}", 
                          "<button onClick={() => featureFlags?.excel_reports === false ? toast.error('Excel Export is not available on Free plan') : handleExport()} disabled={report.length === 0 || featureFlags?.excel_reports === false}")

content = content.replace("<button onClick={handleExportPDF} disabled={report.length === 0}", 
                          "<button onClick={() => featureFlags?.pdf_reports === false ? toast.error('PDF Export is not available on Free plan') : handleExportPDF()} disabled={report.length === 0 || featureFlags?.pdf_reports === false}")

with open(filepath, 'w') as f:
    f.write(content)

