# TODO - Fix app stuck on loading

- [ ] Add timeout + safe fallback to `AuthService.checkCurrentUser()` so splash never hangs indefinitely
- [ ] Add timeout + error handling in `SplashScreen._checkAuth()` to always navigate
- [ ] (Optional) Guard/disable temporary Firestore audit listener in `main.dart` if it affects startup
- [ ] Run `flutter clean && flutter pub get` and verify splash transitions to login/role screen

