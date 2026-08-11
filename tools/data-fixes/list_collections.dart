import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Unfortunately, Flutter Firestore SDK doesn't support listing root collections directly.
  // I need to use the REST API or ask the user.
}
