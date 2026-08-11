import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import time

try:
    cred = credentials.Certificate('Trackify_Admin/serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

db.collection('support_tickets').add({
    'issue': "My app keeps crashing when I scan a QR code! I'm stuck on site, please help me immediately!",
    'status': 'Open',
    'priority': 'High',
    'userId': 'user_123',
    'history': [{
      'type': 'status_change',
      'text': 'Ticket created',
      'timestamp': firestore.SERVER_TIMESTAMP
    }],
    'createdAt': firestore.SERVER_TIMESTAMP
})

print("Injected Support Ticket!")
