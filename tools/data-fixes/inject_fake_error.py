import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

try:
    cred = credentials.Certificate('Trackify_Admin/serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

db.collection('error_logs').add({
    'message': '[FAKE ERROR] Connection to Main Tracking Node Lost.',
    'stackTrace': 'Exception: SocketTimeout\\n  at TrackingService.sync (tracking_service.dart:45)',
    'type': 'Network Error',
    'severity': 'HIGH',
    'status': 'NEW',
    'module': 'Tracking Node',
    'createdAt': firestore.SERVER_TIMESTAMP,
    'userId': 'admin_test'
})

print("Injected fake error!")
