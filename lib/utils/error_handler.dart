import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error is FirebaseException) {
      return _mapFirebaseError(error.code);
    }
    
    if (error is PlatformException) {
      return _mapPlatformError(error.code);
    }

    if (error is SocketException || error is TimeoutException) {
      return "Network connection issue. Please check your internet and try again.";
    }

    // Generic fallback for unhandled exceptions
    return "Something went wrong. Please try again.";
  }

  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'permission-denied':
        return "You don't have permission to perform this action.";
      case 'unauthenticated':
        return "Your session has expired. Please sign in again.";
      case 'unavailable':
        return "Service temporarily unavailable. Please try again.";
      case 'deadline-exceeded':
        return "The request took too long. Please try again.";
      case 'not-found':
        return "This information is no longer available.";
      case 'already-exists':
        return "This record already exists.";
      case 'resource-exhausted':
        return "Service is temporarily busy. Please try again later.";
      case 'network-request-failed':
        return "Network connection lost. Please check your internet.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'invalid-argument':
        return "Invalid request. Please check your input.";
      default:
        return "Something went wrong. Please try again.";
    }
  }

  static String _mapPlatformError(String code) {
    switch (code) {
      case 'camera_access_denied':
        return "Camera permission is required to scan attendance.";
      default:
        return "A system error occurred. Please try again.";
    }
  }
}
