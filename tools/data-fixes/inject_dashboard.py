import re
import os

filepath = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/Dashboard.jsx'

with open(filepath, 'r') as f:
    content = f.read()

if 'useSubscriptionStore' not in content:
    content = content.replace("import { useAuthStore, useScopeId } from '../store/authStore';", "import { useAuthStore, useScopeId } from '../store/authStore';\nimport { useSubscriptionStore } from '../store/subscriptionStore';")

# Find the start of Dashboard()
content = content.replace("export default function Dashboard() {", "export default function Dashboard() {\n  const { subscription } = useSubscriptionStore();")

# Inject the Trial Badge in the Welcome header
# Let's find: <p className="text-text-muted mt-0.5 mb-5 text-[13px]">{toDateKey(new Date())}</p> or similar
# Wait, let's look at the render block of Dashboard.jsx first.
