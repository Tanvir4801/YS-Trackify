import re
import os

filepath = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/superadmin/SADashboard.jsx'

with open(filepath, 'r') as f:
    content = f.read()

# Remove useMemo for kpi and plans
content = content.replace("const kpi = useMemo(() => getSAKPIs(), []);", "")
content = content.replace("const plans = useMemo(() => getPlanBreakdown(), []);", "")
content = content.replace("const topCustomers = useMemo(() => [...allCustomers].filter(c => c.status === 'active').sort((a, b) => b.mrr - a.mrr).slice(0, 5), []);", "")

# We need to inject them in the useEffect
injection = """
  const [kpi, setKpi] = useState({ mrr: 0, arr: 0, active: 0, trial: 0, expired: 0, totalLabours: 0, totalSites: 0, pending: 0 });
  const [plans, setPlans] = useState([]);
  const [topCustomers, setTopCustomers] = useState([]);

  useEffect(() => {
    getSAKPIs().then(setKpi);
    getPlanBreakdown().then(setPlans);
  }, []);

  useEffect(() => {
    setTopCustomers([...allCustomers].filter(c => c.status === 'active').sort((a, b) => b.mrr - a.mrr).slice(0, 5));
  }, [allCustomers]);
"""
# Insert after setLoadingCustomers(false);});}, []);
content = content.replace("setLoadingCustomers(false);\n    });\n  }, []);", "setLoadingCustomers(false);\n    });\n  }, []);\n" + injection)

with open(filepath, 'w') as f:
    f.write(content)

filepath_subs = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/superadmin/SASubscriptions.jsx'
if os.path.exists(filepath_subs):
    with open(filepath_subs, 'r') as f:
        content = f.read()
    content = content.replace("const plans = useMemo(() => getPlanBreakdown(), []);", "")
    injection = """
  const [plans, setPlans] = useState([]);
  useEffect(() => {
    getPlanBreakdown().then(setPlans);
  }, []);
"""
    content = content.replace("setLoadingCustomers(false);\n    });\n  }, []);", "setLoadingCustomers(false);\n    });\n  }, []);\n" + injection)
    with open(filepath_subs, 'w') as f:
        f.write(content)

filepath_insights = '/Users/tanuuux_/Documents/Trackify_Live/YS-Trackify/Trackify_Admin/src/pages/superadmin/SAInsights.jsx'
if os.path.exists(filepath_insights):
    with open(filepath_insights, 'r') as f:
        content = f.read()
    content = content.replace("const kpi = useMemo(() => getSAKPIs(), []);", "")
    injection = """
  const [kpi, setKpi] = useState({ mrr: 0, arr: 0, active: 0, trial: 0, expired: 0, totalLabours: 0, totalSites: 0, pending: 0 });
  useEffect(() => {
    getSAKPIs().then(setKpi);
  }, []);
"""
    content = content.replace("setLoadingCustomers(false);\n    });\n  }, []);", "setLoadingCustomers(false);\n    });\n  }, []);\n" + injection)
    with open(filepath_insights, 'w') as f:
        f.write(content)

