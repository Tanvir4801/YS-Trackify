import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService._privateConstructor();
  static final StorageService instance = StorageService._privateConstructor();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file from a mobile device (using File)
  Future<String?> uploadFile(File file, String folder, {String? fileName}) async {
    try {
      final name = fileName ?? const Uuid().v4();
      final ext = file.path.split('.').last;
      final ref = _storage.ref().child('$folder/$name.$ext');
      
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('[StorageService] Error uploading file: $e');
      return null;
    }
  }

  /// Uploads raw bytes (useful for Flutter Web)
  Future<String?> uploadBytes(Uint8List bytes, String folder, String extension, {String? fileName}) async {
    try {
      final name = fileName ?? const Uuid().v4();
      final ref = _storage.ref().child('$folder/$name.$extension');
      
      final uploadTask = await ref.putData(bytes);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('[StorageService] Error uploading bytes: $e');
      return null;
    }
  }

  // ── Specific Helper Methods ──────────────────────────────────────────────────

  Future<String?> uploadLabourPhoto(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/profile', fileName: fileName);
  }

  Future<String?> uploadLabourDocument(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/labours', fileName: fileName);
  }

  Future<String?> uploadMaterialBill(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/materials', fileName: fileName);
  }

  Future<String?> uploadDailyReportPDF(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/pdfReports', fileName: fileName);
  }

  Future<String?> uploadSalarySlip(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/salarySlips', fileName: fileName);
  }

  Future<String?> uploadSiteImage(String contractorId, File file, {String? fileName}) {
    return uploadFile(file, 'contractors/$contractorId/dailySitePhotos', fileName: fileName);
  }
}
