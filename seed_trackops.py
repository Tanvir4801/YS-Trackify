import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from datetime import datetime, timezone

try:
    # Initialize Firebase Admin (assuming default credentials/env variables are set up similar to other scripts in this project)
    if not firebase_admin._apps:
        cred = credentials.Certificate('Trackify_Admin/serviceAccountKey.json') # fallback or adjust based on env
        firebase_admin.initialize_app(cred)
except:
    try:
        firebase_admin.initialize_app()
    except Exception as e:
        print("Could not initialize firebase:", e)

try:
    db = firestore.client()

    # 1. Initialize System Health
    db.collection('system_status').document('health').set({
        'crashRate': 0.5,
        'latencyScore': 1.2,
        'apiFailures': 0.1,
        'criticalIssues': 0,
        'maintenance': False,
        'lastUpdated': firestore.SERVER_TIMESTAMP
    }, merge=True)
    
    print("Successfully seeded TrackOps system_status config in Firestore.")
except Exception as e:
    print(f"Error seeding TrackOps data: {e}")
