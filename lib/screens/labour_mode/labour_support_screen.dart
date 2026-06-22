import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/labour_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourSupportScreen extends StatefulWidget {
  const LabourSupportScreen({
    super.key,
    required this.labour,
    required this.firestoreService,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;

  @override
  State<LabourSupportScreen> createState() => _LabourSupportScreenState();
}

class _LabourSupportScreenState extends State<LabourSupportScreen> {
  Map<String, dynamic>? _supervisor;
  bool _isLoading = true;
  bool _isHindi = false; // Language toggle state

  final Map<String, Map<String, String>> _translations = {
    'title': {
      'gu': 'હેલ્પ અને સપોર્ટ',
      'hi': 'हेल्प और सपोर्ट',
    },
    'subtitle': {
      'gu': 'કોઈપણ સમસ્યા હોય તો નીચેના વિકલ્પોમાંથી પસંદ કરો.',
      'hi': 'कोई भी समस्या हो तो नीचे दिए गए विकल्पों में से चुनें।',
    },
    'call_supervisor_title': {
      'gu': '👷 સુપરવાઇઝરનો સંપર્ક',
      'hi': '👷 सुपरवाइजर से संपर्क करें',
    },
    'call_supervisor_subtitle': {
      'gu': 'સાઇટના સુપરવાઇઝરને સીધો ફોન કરો.',
      'hi': 'साइट के सुपरवाइजर को सीधा फोन करें।',
    },
    'call_btn': {
      'gu': 'ફોન કરો',
      'hi': 'फोन करें',
    },
    'whatsapp_title': {
      'gu': '💬 વોટ્સએપ સહાય',
      'hi': '💬 व्हाट्सएप सहायता',
    },
    'whatsapp_subtitle': {
      'gu': 'અમને વોટ્સએપ પર મેસેજ મોકલો.',
      'hi': 'हमें व्हाट्सएप पर मैसेज भेजें।',
    },
    'whatsapp_btn': {
      'gu': 'વોટ્સએપ કરો',
      'hi': 'व्हाट्सएप करें',
    },
    'attendance_title': {
      'gu': '📅 હાજરી અંગે સમસ્યા',
      'hi': '📅 हाजिरी से जुड़ी समस्या',
    },
    'attendance_subtitle': {
      'gu': 'હાજરી લાગી ના હોય કે ખોટી લાગી હોય.',
      'hi': 'हाजिरी नहीं लगी है या गलत लगी है।',
    },
    'report_issue_btn': {
      'gu': 'સમસ્યા જણાવો',
      'hi': 'समस्या बताएं',
    },
    'payment_title': {
      'gu': '₹ પગાર અંગે માહિતી',
      'hi': '₹ सैलरी की जानकारी',
    },
    'payment_subtitle': {
      'gu': 'તમારો પગાર સંબંધિત પ્રશ્ન પૂછો.',
      'hi': 'अपनी सैलरी से जुड़ा सवाल पूछें।',
    },
    'ask_payment_btn': {
      'gu': 'પગાર વિશે પૂછો',
      'hi': 'सैलरी के बारे में पूछें',
    },
    'site_title': {
      'gu': '📍 આજની સાઇટ',
      'hi': '📍 आज की साइट',
    },
    'supervisor_label': {
      'gu': 'સુપરવાઇઝર',
      'hi': 'सुपरवाइजर',
    },
    'emergency_title': {
      'gu': '🚨 ઇમરજન્સી સહાય',
      'hi': '🚨 इमरजेंसी सहायता',
    },
    'emergency_subtitle': {
      'gu': 'જો કોઈ અકસ્માત કે તાત્કાલિક મદદની જરૂર હોય.',
      'hi': 'अगर कोई दुर्घटना हो या तुरंत मदद चाहिए।',
    },
    'faq_title': {
      'gu': 'FAQ - વારંવાર પૂછાતા પ્રશ્નો',
      'hi': 'FAQ - अक्सर पूछे जाने वाले सवाल',
    },
    'faq_1_q': {
      'gu': 'મારો QR કોડ કામ કરતો નથી?',
      'hi': 'मेरा QR कोड काम नहीं कर रहा है?',
    },
    'faq_1_a': {
      'gu': 'સુપરવાઇઝરને બતાવો અથવા વોટ્સએપ દ્વારા સંપર્ક કરો.',
      'hi': 'सुपरवाइजर को दिखाएं या व्हाट्सएप पर संपर्क करें।',
    },
    'faq_2_q': {
      'gu': 'મારો પગાર ક્યાં જોઈ શકું?',
      'hi': 'मैं अपनी सैलरी कहाँ देख सकता हूँ?',
    },
    'faq_2_a': {
      'gu': 'Earnings વિભાગમાં જોઈ શકો છો.',
      'hi': 'Earnings सेक्शन में देख सकते हैं।',
    },
    'faq_3_q': {
      'gu': 'મારી હાજરી ખોટી લાગી છે?',
      'hi': 'मेरी हाजिरी गलत लगी है?',
    },
    'faq_3_a': {
      'gu': 'હાજરી અંગે સમસ્યા વિકલ્પમાંથી જાણ કરો.',
      'hi': 'हाजिरी की समस्या विकल्प से बताएं।',
    },
    'faq_4_q': {
      'gu': 'મારું ID કાર્ડ કેવી રીતે વાપરવું?',
      'hi': 'मेरा ID कार्ड कैसे इस्तेमाल करें?',
    },
    'faq_4_a': {
      'gu': 'ID Card વિભાગમાં જઈને સુપરવાઇઝરને તમારો QR કોડ બતાવો.',
      'hi': 'ID Card सेक्शन में जाकर सुपरवाइजर को अपना QR कोड दिखाएं।',
    },
    'faq_5_q': {
      'gu': 'એડવાન્સ પૈસા કેવી રીતે મળશે?',
      'hi': 'एडवांस पैसे कैसे मिलेंगे?',
    },
    'faq_5_a': {
      'gu': 'પગાર અંગે માહિતી વિકલ્પમાંથી પૂછો અથવા સુપરવાઇઝરનો સંપર્ક કરો.',
      'hi': 'सैलरी की जानकारी विकल्प से पूछें या सुपरवाइजर से संपर्क करें।',
    },
    'faq_6_q': {
      'gu': 'એપ બરાબર ચાલતી નથી, શું કરવું?',
      'hi': 'ऐप ठीक से नहीं चल रहा है, क्या करें?',
    },
    'faq_6_a': {
      'gu': 'એપ બંધ કરી ફરીથી ચાલુ કરો, અથવા સુપરવાઇઝરને જાણ કરો.',
      'hi': 'ऐप बंद करके फिर से चालू करें, या सुपरवाइजर को बताएं।',
    },
    'no_phone': {
      'gu': 'ફોન નંબર ઉપલબ્ધ નથી',
      'hi': 'फोन नंबर उपलब्ध नहीं है',
    },
    'no_call': {
      'gu': 'કૉલ કરી શકાતો નથી',
      'hi': 'कॉल नहीं किया जा सकता',
    },
    'no_whatsapp': {
      'gu': 'વોટ્સએપ નંબર ઉપલબ્ધ નથી',
      'hi': 'व्हाट्सएप नंबर उपलब्ध नहीं है',
    },
    'no_open_whatsapp': {
      'gu': 'વોટ્સએપ ખોલી શકાતું નથી',
      'hi': 'व्हाट्सएप नहीं खुल रहा है',
    },
    'success_msg': {
      'gu': 'તમારી સમસ્યા નોંધાઈ ગઈ છે. અમે ટૂંક સમયમાં સંપર્ક કરીશું.',
      'hi': 'आपकी समस्या दर्ज हो गई है। हम जल्द ही संपर्क करेंगे।',
    },
    'error_msg': {
      'gu': 'સમસ્યા નોંધવામાં ભૂલ આવી છે. ફરી પ્રયાસ કરો.',
      'hi': 'समस्या दर्ज करने में त्रुटि आई है। फिर से प्रयास करें।',
    },
  };

  String _t(String key) {
    return _translations[key]![_isHindi ? 'hi' : 'gu']!;
  }

  @override
  void initState() {
    super.initState();
    _loadSupervisorDetails();
  }

  Future<void> _loadSupervisorDetails() async {
    final sup = await widget.firestoreService.getSupervisor(widget.labour.supervisorId);
    if (mounted) {
      setState(() {
        _supervisor = sup;
        _isLoading = false;
      });
    }
  }

  Future<void> _callNumber(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('no_phone'))));
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('no_call'))));
      }
    }
  }

  Future<void> _openWhatsApp() async {
    String phone = _supervisor?['phone'] ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('no_whatsapp'))));
      return;
    }
    
    // Remove formatting characters from phone
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!phone.startsWith('+')) {
      phone = '+91$phone'; // Default to +91 if no country code
    }

    final messageGu = '''નમસ્તે સાહેબ,

મારું નામ ${widget.labour.name} છે.

મને નીચેની બાબતમાં મદદ જોઈએ છે:

• હાજરી અંગે સમસ્યા
• પગાર અંગે પ્રશ્ન
• સાઇટ અંગે માહિતી
• QR કોડ અંગે સમસ્યા
• અન્ય

મહેરબાની કરીને મારી મદદ કરશો.

આભાર.''';

    final messageHi = '''नमस्ते सर,

मेरा नाम ${widget.labour.name} है।

मुझे नीचे दी गई बातों में मदद चाहिए:

• हाजिरी से जुड़ी समस्या
• सैलरी का सवाल
• साइट की जानकारी
• QR कोड की समस्या
• अन्य

कृपया मेरी मदद करें।

धन्यवाद।''';

    final message = _isHindi ? messageHi : messageGu;

    final Uri url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('no_open_whatsapp'))));
      }
    }
  }

  Future<void> _submitSupportRequest(String issueType, String description) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );

      final requestId = const Uuid().v4();
      final requestData = {
        'requestId': requestId,
        'labourId': widget.labour.id,
        'labourName': widget.labour.name,
        'siteId': _supervisor?['activeSiteId'] ?? '',
        'siteName': _supervisor?['activeSiteName'] ?? (_isHindi ? 'अज्ञात साइट' : 'અજાણી સાઇટ'),
        'issueType': issueType,
        'description': description,
        'date': AppDateUtils.toDateKey(DateTime.now()),
        'status': 'Pending',
        'createdAt': DateTime.now(),
      };

      await widget.firestoreService.submitSupportRequest(requestData);

      if (mounted) {
        Navigator.of(context).pop(); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('success_msg'))));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_msg'))));
      }
    }
  }

  void _showAttendancePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final optionsGu = [
          'હાજરી લાગી નથી',
          'ખોટી હાજરી લાગી છે',
          'અડધા દિવસની સમસ્યા',
          'ખોટી સાઇટમાં હાજરી લાગી',
          'અન્ય સમસ્યા'
        ];
        final optionsHi = [
          'हाजिरी नहीं लगी है',
          'गलत हाजिरी लगी है',
          'हाफ डे की समस्या',
          'गलत साइट पर हाजिरी लगी',
          'अन्य समस्या'
        ];
        final options = _isHindi ? optionsHi : optionsGu;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('attendance_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...options.map((opt) => ListTile(
                  title: Text(opt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textTertiary, size: 16),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _submitSupportRequest('Attendance', opt);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final optionsGu = [
          'પગાર મળ્યો નથી',
          'પગાર ઓછો આવ્યો છે',
          'એડવાન્સની માહિતી ખોટી છે',
          'અન્ય પ્રશ્ન'
        ];
        final optionsHi = [
          'सैलरी नहीं मिली है',
          'सैलरी कम आई है',
          'एडवांस की जानकारी गलत है',
          'अन्य सवाल'
        ];
        final options = _isHindi ? optionsHi : optionsGu;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('payment_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...options.map((opt) => ListTile(
                  title: Text(opt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textTertiary, size: 16),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _submitSupportRequest('Payment', opt);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    final supervisorName = _supervisor?['name'] ?? (_isHindi ? 'उपलब्ध नहीं' : 'ઉપલબ્ધ નથી');
    final supervisorPhone = _supervisor?['phone'] ?? '';
    final siteName = _supervisor?['activeSiteName'] ?? (_isHindi ? 'कोई साइट नहीं' : 'કોઈ સાઇટ નથી');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('title'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () {
                  setState(() {
                    _isHindi = !_isHindi;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _isHindi ? 'અ' : 'अ', // Show the opposite language character
                    style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_t('subtitle'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          
          _SupportCard(
            title: _t('call_supervisor_title'),
            subtitle: '${_t('call_supervisor_subtitle')}\n\n${_t('supervisor_label')}: $supervisorName\nMobile: $supervisorPhone',
            buttonText: _t('call_btn'),
            buttonColor: AppColors.gold,
            onPressed: () => _callNumber(supervisorPhone),
          ),
          
          const SizedBox(height: 16),
          
          _SupportCard(
            title: _t('whatsapp_title'),
            subtitle: _t('whatsapp_subtitle'),
            buttonText: _t('whatsapp_btn'),
            buttonColor: const Color(0xFF25D366),
            onPressed: _openWhatsApp,
          ),
          
          const SizedBox(height: 16),
          
          _SupportCard(
            title: _t('attendance_title'),
            subtitle: _t('attendance_subtitle'),
            buttonText: _t('report_issue_btn'),
            buttonColor: AppColors.navyLight,
            onPressed: _showAttendancePopup,
          ),
          
          const SizedBox(height: 16),
          
          _SupportCard(
            title: _t('payment_title'),
            subtitle: _t('payment_subtitle'),
            buttonText: _t('ask_payment_btn'),
            buttonColor: AppColors.navyLight,
            onPressed: _showPaymentPopup,
          ),

          const SizedBox(height: 16),

          _SupportCard(
            title: _t('site_title'),
            subtitle: '$siteName\n${_t('supervisor_label')}: $supervisorName',
            buttonText: _t('call_btn'),
            buttonColor: AppColors.navyLight,
            onPressed: () => _callNumber(supervisorPhone),
          ),

          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.absent.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('emergency_title'), style: const TextStyle(color: AppColors.absent, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_t('emergency_subtitle'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.absent, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _callNumber(supervisorPhone),
                    child: Text(_t('call_btn'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(_t('faq_title'), style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          _FaqItem(
            question: _t('faq_1_q'),
            answer: _t('faq_1_a'),
          ),
          _FaqItem(
            question: _t('faq_2_q'),
            answer: _t('faq_2_a'),
          ),
          _FaqItem(
            question: _t('faq_3_q'),
            answer: _t('faq_3_a'),
          ),
          _FaqItem(
            question: _t('faq_4_q'),
            answer: _t('faq_4_a'),
          ),
          _FaqItem(
            question: _t('faq_5_q'),
            answer: _t('faq_5_a'),
          ),
          _FaqItem(
            question: _t('faq_6_q'),
            answer: _t('faq_6_a'),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: buttonColor == AppColors.gold ? AppColors.navy : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onPressed,
              child: Text(buttonText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.textTertiary,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(answer, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
          )
        ],
      ),
    );
  }
}
