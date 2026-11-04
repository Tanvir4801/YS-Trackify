import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FieldReferenceScreen extends StatefulWidget {
  const FieldReferenceScreen({super.key});

  @override
  State<FieldReferenceScreen> createState() => _FieldReferenceScreenState();
}

class _FieldReferenceScreenState extends State<FieldReferenceScreen> {
  // 0 = English, 1 = Hindi, 2 = Gujarati
  int _languageIndex = 0;

  final List<String> _languages = ['English', 'हिंदी', 'ગુજરાતી'];

  // Data structure: sectionTitle, items (title, description)
  final Map<int, List<Map<String, dynamic>>> _content = {
    0: [
      {
        'section': 'Measurements (Civil)',
        'items': [
          {'title': '1 Meter', 'desc': '3.28 Feet / 39.37 Inches'},
          {'title': '1 Foot', 'desc': '12 Inches / 30.48 cm'},
          {'title': '1 Inch', 'desc': '25.4 mm'},
          {'title': '1 Brass (Volume)', 'desc': '100 Cubic Feet (cft)'},
        ]
      },
      {
        'section': 'Safety Rules',
        'items': [
          {'title': 'Helmet (Hard Hat)', 'desc': 'Must be worn at all times on site.'},
          {'title': 'Safety Shoes', 'desc': 'Protect feet from nails and heavy objects.'},
          {'title': 'Harness', 'desc': 'Required for working at heights above 2 meters.'},
        ]
      },
      {
        'section': 'Common Terms',
        'items': [
          {'title': 'PCC', 'desc': 'Plain Cement Concrete (Base layer)'},
          {'title': 'RCC', 'desc': 'Reinforced Cement Concrete (With steel bars)'},
          {'title': 'Curing', 'desc': 'Watering concrete to gain strength'},
        ]
      },
    ],
    1: [
      {
        'section': 'माप (सिविल)',
        'items': [
          {'title': '1 मीटर', 'desc': '3.28 फीट / 39.37 इंच'},
          {'title': '1 फुट', 'desc': '12 इंच / 30.48 सेमी'},
          {'title': '1 इंच', 'desc': '25.4 मिमी'},
          {'title': '1 ब्रास (वॉल्यूम)', 'desc': '100 क्यूबिक फीट (cft)'},
        ]
      },
      {
        'section': 'सुरक्षा नियम',
        'items': [
          {'title': 'हेलमेट', 'desc': 'साइट पर हमेशा पहनना अनिवार्य है।'},
          {'title': 'सुरक्षा जूते', 'desc': 'कीलों और भारी चीजों से पैरों को बचाएं।'},
          {'title': 'हार्नेस (बेल्ट)', 'desc': '2 मीटर से ऊपर काम करने के लिए जरूरी।'},
        ]
      },
      {
        'section': 'आम शब्द',
        'items': [
          {'title': 'पी.सी.सी (PCC)', 'desc': 'प्लेन सीमेंट कंक्रीट (बेस लेयर)'},
          {'title': 'आर.सी.सी (RCC)', 'desc': 'स्टील बार के साथ सीमेंट कंक्रीट'},
          {'title': 'क्यूरिंग', 'desc': 'मजबूती के लिए कंक्रीट में पानी डालना (तराई)'},
        ]
      },
    ],
    2: [
      {
        'section': 'માપ (સિવિલ)',
        'items': [
          {'title': '1 મીટર', 'desc': '3.28 ફૂટ / 39.37 ઈંચ'},
          {'title': '1 ફૂટ', 'desc': '12 ઈંચ / 30.48 સેમી'},
          {'title': '1 ઈંચ', 'desc': '25.4 મીમી'},
          {'title': '1 બ્રાસ (વોલ્યુમ)', 'desc': '100 ક્યુબિક ફૂટ (cft)'},
        ]
      },
      {
        'section': 'સલામતીના નિયમો',
        'items': [
          {'title': 'હેલ્મેટ', 'desc': 'સાઇટ પર હંમેશાં પહેરવું ફરજિયાત છે.'},
          {'title': 'સેફ્ટી શૂઝ', 'desc': 'ખીલાઓ અને ભારે વસ્તુઓથી પગનું રક્ષણ.'},
          {'title': 'હાર્નેસ (બેલ્ટ)', 'desc': '2 મીટરથી ઉપર કામ કરતી વખતે જરૂરી.'},
        ]
      },
      {
        'section': 'સામાન્ય શબ્દો',
        'items': [
          {'title': 'PCC', 'desc': 'પ્લેન સિમેન્ટ કોંક્રિટ (બેઝ લેયર)'},
          {'title': 'RCC', 'desc': 'સ્ટીલ સાથે સિમેન્ટ કોંક્રિટ'},
          {'title': 'ક્યોરિંગ', 'desc': 'મજબૂતી માટે કોંક્રિટમાં પાણી છાંટવું (તરાઈ)'},
        ]
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final content = _content[_languageIndex]!;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimaryColor(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _languageIndex == 0 ? 'Field Reference' : 
          _languageIndex == 1 ? 'फील्ड संदर्भ' : 'સાઇટ સંદર્ભ',
          style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Language toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderColor(context))),
            ),
            child: Row(
              children: List.generate(_languages.length, (index) {
                final isSelected = _languageIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _languageIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryColor(context).withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppColors.primaryColor(context) : Colors.transparent),
                      ),
                      child: Text(
                        _languages[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryColor(context) : AppColors.textSecondaryColor(context),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: content.length,
              itemBuilder: (context, index) {
                final section = content[index];
                final items = section['items'] as List<Map<String, dynamic>>;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['section'],
                        style: TextStyle(color: AppColors.primaryColor(context), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderColor(context)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor(context).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.info_outline_rounded, color: AppColors.primaryColor(context), size: 16),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'], style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(item['desc'], style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
