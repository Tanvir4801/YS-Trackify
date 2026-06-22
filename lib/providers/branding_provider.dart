import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BrandingData {
  final String companyName;
  final String tagline;
  final String address;
  final String phone;
  final String email;
  final String gstNumber;
  final String? logoUrl;
  final Color themeColor;
  final Color themeColorDark;
  final Color themeColorLight;
  final String pdfHeaderNote;
  final String invoicePrefix;
  final bool isSetup;

  const BrandingData({
    required this.companyName,
    this.tagline = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.gstNumber = '',
    this.logoUrl,
    required this.themeColor,
    required this.themeColorDark,
    required this.themeColorLight,
    this.pdfHeaderNote = 'Thank you',
    this.invoicePrefix = 'INV',
    this.isSetup = false,
  });

  static const fallback = BrandingData(
    companyName:    'My Company',
    themeColor:     Color(0xFF10141C),
    themeColorDark: Color(0xFF0A0C11),
    themeColorLight:Color(0xFF1A2438),
  );

  factory BrandingData.fromMap(
    Map<String, dynamic> map, String fallbackName) {
    final hex = map['themeColor'] as String? ?? '#10141C';
    final color = _hexToColor(hex);
    return BrandingData(
      companyName:  map['companyName'] ?? fallbackName,
      tagline:      map['tagline'] ?? '',
      address:      map['address'] ?? '',
      phone:        map['phone'] ?? '',
      email:        map['email'] ?? '',
      gstNumber:    map['gstNumber'] ?? '',
      logoUrl:      map['logoUrl'],
      themeColor:     color,
      themeColorDark: _darken(color, 0.2),
      themeColorLight:_lighten(color, 0.4),
      pdfHeaderNote:  map['pdfHeaderNote'] ?? 'Thank you',
      invoicePrefix:  map['invoicePrefix'] ?? 'INV',
      isSetup:        map['isSetup'] ?? false,
    );
  }
  
  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#','');
    return Color(int.parse('FF$h', radix: 16));
  }
  
  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0)
    ).toColor();
  }
  
  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0)
    ).toColor();
  }
}

class BrandingProvider extends ChangeNotifier {
  BrandingData _branding = BrandingData.fallback;
  bool _loading = true;
  
  BrandingData get branding => _branding;
  bool get loading => _loading;

  void loadBranding(String contractorId, String fallbackName) {
    FirebaseFirestore.instance
      .collection('contractors')
      .doc(contractorId)
      .snapshots()
      .listen((snap) {
        if (snap.exists) {
          final map = snap.data() as Map<String, dynamic>;
          final b = map['branding'] as Map<String, dynamic>? ?? {};
          _branding = BrandingData.fromMap(b, fallbackName);
        }
        _loading = false;
        notifyListeners();
      });
  }
}
