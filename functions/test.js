const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
db.collection('users').where('email', '==', 'shirish@ysconstruction.com').get().then(snap => {
  snap.forEach(doc => console.log(doc.id, doc.data().role));
}).catch(console.error);
