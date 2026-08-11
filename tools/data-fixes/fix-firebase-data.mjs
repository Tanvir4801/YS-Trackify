import { initializeApp } from "firebase/app";
import { getFirestore, collection, getDocs, updateDoc, doc, collectionGroup } from "firebase/firestore";

const firebaseConfig = {
  // need to get the config from src/lib/firebase.js
};
