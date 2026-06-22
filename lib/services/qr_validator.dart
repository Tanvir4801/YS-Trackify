import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class QRValidator {
  static const String _salt = 'TRACKIFY_QR_SECRET_2026';

  static QRValidationResult validate(String rawToken) {
    try {
      final decoded = utf8.decode(base64Url.decode(rawToken));
      final parts   = decoded.split('|');

      if (parts.length != 3) {
        return QRValidationResult.invalid('Bad token format');
      }

      final labourId      = parts[0];
      final windowStr     = parts[1];
      final receivedSig   = parts[2];
      final windowSeconds = int.tryParse(windowStr);

      if (labourId.isEmpty || windowSeconds == null) {
        return QRValidationResult.invalid('Missing token fields');
      }

      final nowWindow = DateTime.now().millisecondsSinceEpoch ~/ 30000;
      if ((nowWindow - windowSeconds).abs() > 2) {
        return QRValidationResult.expired();
      }

      final payload     = '$labourId|$windowSeconds';
      final key         = utf8.encode(_salt);
      final bytes       = utf8.encode(payload);
      final hmac        = Hmac(sha256, key);
      final digest      = hmac.convert(bytes);
      final expectedSig = digest.toString().substring(0, 16);

      if (receivedSig != expectedSig) {
        debugPrint('QR signature mismatch');
        return QRValidationResult.invalid('Invalid signature');
      }

      return QRValidationResult.valid(
        labourId:      labourId,
        windowSeconds: windowSeconds,
      );
    } catch (e) {
      debugPrint('QRValidator error: $e');
      return QRValidationResult.invalid('Token decode failed');
    }
  }
}

enum QRValidationStatus { valid, expired, invalid }

class QRValidationResult {
  const QRValidationResult._({
    required this.status,
    this.labourId,
    this.windowSeconds,
    this.errorMessage,
  });

  final QRValidationStatus status;
  final String?            labourId;
  final int?               windowSeconds;
  final String?            errorMessage;

  bool get isValid   => status == QRValidationStatus.valid;
  bool get isExpired => status == QRValidationStatus.expired;

  factory QRValidationResult.valid({
    required String labourId,
    required int windowSeconds,
  }) => QRValidationResult._(
    status:        QRValidationStatus.valid,
    labourId:      labourId,
    windowSeconds: windowSeconds,
  );

  factory QRValidationResult.expired() => const QRValidationResult._(
    status:       QRValidationStatus.expired,
    errorMessage: 'QR code expired. Ask labour to refresh.',
  );

  factory QRValidationResult.invalid(String reason) => QRValidationResult._(
    status:       QRValidationStatus.invalid,
    errorMessage: reason,
  );
}
