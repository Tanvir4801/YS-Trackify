import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/calc_constants.dart';
import '../utils/calc_formulas.dart';
import '../widgets/calc_input_field.dart';
import '../widgets/calc_select_field.dart';
import '../widgets/calc_button.dart';
import '../widgets/result_card.dart';
import '../widgets/calc_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/is_code_badge.dart';
import '../widgets/utilisation_bar.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';

class StructuralScreen extends StatefulWidget {
  const StructuralScreen({super.key});

  @override
  State<StructuralScreen> createState() => _StructuralScreenState();
}

class _StructuralScreenState extends State<StructuralScreen> {
  String _selectedSubCat = 'Beam'; // Beam, Column, Load, Staircase
  
  // Beam
  final _beamSpanCtrl = TextEditingController(text: '6');
  final _beamWidthCtrl = TextEditingController(text: '230');
  final _beamDepthCtrl = TextEditingController(text: '450');
  final _beamLoadCtrl = TextEditingController(text: '25');
  String _beamFck = '20';
  String _beamFy = '415';

  // Column
  final _colWidthCtrl = TextEditingController(text: '230');
  final _colDepthCtrl = TextEditingController(text: '450');
  final _colSteelCtrl = TextEditingController(text: '1.2');
  final _colLoadCtrl = TextEditingController(text: '800');
  String _colFck = '20';

  // Load Bearing
  final _loadLenCtrl = TextEditingController(text: '3.5');
  final _loadHtCtrl = TextEditingController(text: '3.0');
  final _loadThickCtrl = TextEditingController(text: '230');
  final _loadStrCtrl = TextEditingController(text: '7.5');
  final _loadAppCtrl = TextEditingController(text: '35');

  // Staircase
  final _stairHtCtrl = TextEditingController(text: '10');
  final _stairRiseCtrl = TextEditingController(text: '6');
  final _stairTreadCtrl = TextEditingController(text: '10');
  final _stairWidCtrl = TextEditingController(text: '3.5');

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLastValues();
  }

  @override
  void dispose() {
    _saveLastValues();
    _beamSpanCtrl.dispose();
    _beamWidthCtrl.dispose();
    _beamDepthCtrl.dispose();
    _beamLoadCtrl.dispose();
    _colWidthCtrl.dispose();
    _colDepthCtrl.dispose();
    _colSteelCtrl.dispose();
    _colLoadCtrl.dispose();
    _loadLenCtrl.dispose();
    _loadHtCtrl.dispose();
    _loadThickCtrl.dispose();
    _loadStrCtrl.dispose();
    _loadAppCtrl.dispose();
    _stairHtCtrl.dispose();
    _stairRiseCtrl.dispose();
    _stairTreadCtrl.dispose();
    _stairWidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSubCat = prefs.getString('calc_struct_cat') ?? 'Beam';
      _beamSpanCtrl.text = prefs.getString('calc_beam_span') ?? '6';
      _beamWidthCtrl.text = prefs.getString('calc_beam_wid') ?? '230';
      _beamDepthCtrl.text = prefs.getString('calc_beam_dep') ?? '450';
      _beamLoadCtrl.text = prefs.getString('calc_beam_load') ?? '25';
      _beamFck = prefs.getString('calc_beam_fck') ?? '20';
      _beamFy = prefs.getString('calc_beam_fy') ?? '415';
    });
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_struct_cat', _selectedSubCat);
    await prefs.setString('calc_beam_span', _beamSpanCtrl.text);
    await prefs.setString('calc_beam_wid', _beamWidthCtrl.text);
    await prefs.setString('calc_beam_dep', _beamDepthCtrl.text);
    await prefs.setString('calc_beam_load', _beamLoadCtrl.text);
    await prefs.setString('calc_beam_fck', _beamFck);
    await prefs.setString('calc_beam_fy', _beamFy);
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    Map<String, dynamic> res;
    String subtitle = '';
    
    if (_selectedSubCat == 'Beam') {
      final span = double.tryParse(_beamSpanCtrl.text) ?? 0;
      final w = double.tryParse(_beamWidthCtrl.text) ?? 0;
      final d = double.tryParse(_beamDepthCtrl.text) ?? 0;
      final load = double.tryParse(_beamLoadCtrl.text) ?? 0;
      final fck = double.tryParse(_beamFck) ?? 20;
      final fy = double.tryParse(_beamFy) ?? 415;

      if (span <= 0 || w <= 0 || d <= 0 || load <= 0) return;

      res = BeamFormulas.calculate(spanM: span, widthMm: w, depthMm: d, fck: fck, fy: fy, loadKNm: load);
      subtitle = 'Span: ${span}m | ${w}x${d}mm | M$fck/Fe$fy';
      
      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Structural',
        title: 'Beam: ${res['safe'] ? "Safe" : "Unsafe"} (Mu: ${res['Mu']})',
        subtitle: subtitle,
        timestamp: DateTime.now(),
      );
      CalcHistoryService.save(item);

    } else if (_selectedSubCat == 'Column') {
      final w = double.tryParse(_colWidthCtrl.text) ?? 0;
      final d = double.tryParse(_colDepthCtrl.text) ?? 0;
      final steel = double.tryParse(_colSteelCtrl.text) ?? 0;
      final load = double.tryParse(_colLoadCtrl.text) ?? 0;
      final fck = double.tryParse(_colFck) ?? 20;

      if (w <= 0 || d <= 0 || steel <= 0 || load <= 0) return;

      res = ColumnFormulas.calculate(widthMm: w, depthMm: d, fck: fck, steelPct: steel, appliedKN: load);
      subtitle = 'Size: ${w}x${d}mm | $steel% steel | M$fck';

    } else if (_selectedSubCat == 'Load') {
      final len = double.tryParse(_loadLenCtrl.text) ?? 0;
      final ht = double.tryParse(_loadHtCtrl.text) ?? 0;
      final thick = double.tryParse(_loadThickCtrl.text) ?? 0;
      final str = double.tryParse(_loadStrCtrl.text) ?? 0;
      final app = double.tryParse(_loadAppCtrl.text) ?? 0;

      if (len <= 0 || ht <= 0 || thick <= 0 || str <= 0 || app <= 0) return;

      res = LoadBearingFormulas.calculate(lengthM: len, heightM: ht, thicknessMm: thick, brickStrengthMPa: str, appliedKNm: app);
      subtitle = 'Wall: ${len}x${ht}m | ${thick}mm thk';

    } else {
      final ht = double.tryParse(_stairHtCtrl.text) ?? 0;
      final r = double.tryParse(_stairRiseCtrl.text) ?? 0;
      final t = double.tryParse(_stairTreadCtrl.text) ?? 0;
      final w = double.tryParse(_stairWidCtrl.text) ?? 0;

      if (ht <= 0 || r <= 0 || t <= 0 || w <= 0) return;

      res = StaircaseFormulas.calculate(heightFt: ht, riserIn: r, treadIn: t, widthFt: w);
      subtitle = 'Stair: ht ${ht}ft | Rise: ${r}in | Tread: ${t}in';
    }

    setState(() => _result = res);
  }

  Widget _buildBeamInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Span (m)', controller: _beamSpanCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Width (mm)', controller: _beamWidthCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Depth (mm)', controller: _beamDepthCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CalcSelectField(
                label: 'Grade (Fck)',
                value: _beamFck,
                items: const [
                  DropdownMenuItem(value: '20', child: Text('M20')),
                  DropdownMenuItem(value: '25', child: Text('M25')),
                  DropdownMenuItem(value: '30', child: Text('M30')),
                ],
                onChanged: (v) { if (v != null) setState(() => _beamFck = v); },
              ),
            ),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(
              child: CalcSelectField(
                label: 'Steel (Fy)',
                value: _beamFy,
                items: const [
                  DropdownMenuItem(value: '415', child: Text('Fe415')),
                  DropdownMenuItem(value: '500', child: Text('Fe500')),
                  DropdownMenuItem(value: '550', child: Text('Fe550')),
                ],
                onChanged: (v) { if (v != null) setState(() => _beamFy = v); },
              ),
            ),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Load (kN/m)', controller: _beamLoadCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildColumnInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Width (mm)', controller: _colWidthCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Depth (mm)', controller: _colDepthCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CalcSelectField(
                label: 'Concrete',
                value: _colFck,
                items: const [
                  DropdownMenuItem(value: '20', child: Text('M20')),
                  DropdownMenuItem(value: '25', child: Text('M25')),
                  DropdownMenuItem(value: '30', child: Text('M30')),
                ],
                onChanged: (v) { if (v != null) setState(() => _colFck = v); },
              ),
            ),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Steel %', controller: _colSteelCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Load (kN)', controller: _colLoadCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Length (m)', controller: _loadLenCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Height (m)', controller: _loadHtCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Thick (mm)', controller: _loadThickCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Brick (MPa)', controller: _loadStrCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Load (kN/m)', controller: _loadAppCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildStairInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Height (ft)', controller: _stairHtCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Width (ft)', controller: _stairWidCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Riser (in)', controller: _stairRiseCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Tread (in)', controller: _stairTreadCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_result == null) return const SizedBox.shrink();

    if (_selectedSubCat == 'Beam') {
      final safe = _result!['safe'] as bool;
      final type = safe ? ResultType.safe : ResultType.unsafe;
      return Column(
        children: [
          ResultCard(
            mainValue: '${safe ? "Safe" : "Unsafe"} — ${_result!['Mu']} kN·m',
            mainLabel: 'Design moment | Capacity ${_result!['Mulim']} kN·m',
            rows: [
              ResultRowData('Factored moment Mu', '${_result!['Mu']} kN·m'),
              ResultRowData('Limiting Mu,lim', '${_result!['Mulim']} kN·m'),
              ResultRowData('Slenderness (L/d)', '${_result!['slenderness']}'),
            ],
            type: type,
            warningText: safe ? null : 'Section overstressed by ${_result!['utilisationPct']}%. Increase depth to at least ${_result!['minDepthNeeded']} mm effective depth.',
            noteText: '* For preliminary sizing only',
          ),
          UtilisationBar(utilisation: _result!['ratio'] as double),
        ],
      );
    } else if (_selectedSubCat == 'Column') {
      final safe = _result!['safe'] as bool;
      final type = safe ? ResultType.safe : ResultType.unsafe;
      return Column(
        children: [
          ResultCard(
            mainValue: '${safe ? "Safe" : "Unsafe"} — ${_colLoadCtrl.text} kN',
            mainLabel: 'Applied Load | Capacity ${_result!['capacity']} kN',
            rows: [
              ResultRowData('Axial Capacity', '${_result!['capacity']} kN'),
              ResultRowData('Gross Area', '${_result!['grossArea']} cm²'),
              ResultRowData('Steel Area', '${_result!['steelArea']} mm²'),
            ],
            type: type,
            warningText: safe ? null : 'Section inadequate. Increase section size or steel %.',
          ),
          UtilisationBar(utilisation: _result!['utilisation'] as double),
        ],
      );
    } else if (_selectedSubCat == 'Load') {
      final safe = _result!['safe'] as bool;
      final type = safe ? ResultType.safe : ResultType.unsafe;
      return Column(
        children: [
          ResultCard(
            mainValue: safe ? "Safe" : "Unsafe",
            mainLabel: 'Capacity ${_result!['capacity']} kN/m',
            rows: [
              ResultRowData('Wall Capacity', '${_result!['capacity']} kN/m'),
              ResultRowData('Slenderness Ratio', '${_result!['sr']}'),
              ResultRowData('Modification factor ks', '${_result!['ks']}'),
            ],
            type: type,
            warningText: safe ? null : 'Wall overstressed.',
          ),
          UtilisationBar(utilisation: _result!['utilisation'] as double),
        ],
      );
    } else {
      final safe = _result!['checkOK'] as bool;
      final type = safe ? ResultType.safe : ResultType.unsafe;
      return ResultCard(
        mainValue: '${_result!['risers']} Risers',
        mainLabel: '${_result!['treads']} Treads',
        rows: [
          ResultRowData('Actual Riser', '${_result!['actualRiser']} in'),
          ResultRowData('Going Distance', '${_result!['goingFt']} ft'),
          ResultRowData('Rule Check', '${_result!['check']} (Target: 24-25.5)'),
        ],
        type: type,
        warningText: safe ? null : 'Proportions fall outside standard comfort rule (2*R + T).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('Structural', style: CalcTextStyles.screenTitle),
        iconTheme: const IconThemeData(color: CalcColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CategoryChip(label: 'Beam', isActive: _selectedSubCat == 'Beam', onTap: () { setState(() { _selectedSubCat = 'Beam'; _result = null; }); }, activeColor: CalcColors.structural),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Column', isActive: _selectedSubCat == 'Column', onTap: () { setState(() { _selectedSubCat = 'Column'; _result = null; }); }, activeColor: CalcColors.structural),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Load bearing', isActive: _selectedSubCat == 'Load', onTap: () { setState(() { _selectedSubCat = 'Load'; _result = null; }); }, activeColor: CalcColors.structural),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Staircase', isActive: _selectedSubCat == 'Staircase', onTap: () { setState(() { _selectedSubCat = 'Staircase'; _result = null; }); }, activeColor: CalcColors.structural),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const ISCodeBadge(),
            CalcCard(
              child: Padding(
                padding: const EdgeInsets.all(CalcDimens.cardPadding),
                child: Builder(builder: (context) {
                  if (_selectedSubCat == 'Beam') return _buildBeamInputs();
                  if (_selectedSubCat == 'Column') return _buildColumnInputs();
                  if (_selectedSubCat == 'Load') return _buildLoadInputs();
                  return _buildStairInputs();
                }),
              ),
            ),
            const SizedBox(height: 8),
            CalcButton(label: 'CALCULATE', color: CalcColors.structural, onPressed: _calculate),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
