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
import '../widgets/calc_result_widgets.dart';

class StructuralScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const StructuralScreen({super.key, this.initialInputs});

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
    if (widget.initialInputs != null) {
      _selectedSubCat = widget.initialInputs!['subCat']?.toString() ?? 'Beam';
      if (_selectedSubCat == 'Beam') {
        _beamSpanCtrl.text = widget.initialInputs!['beamSpan']?.toString() ?? '';
        _beamWidthCtrl.text = widget.initialInputs!['beamWid']?.toString() ?? '';
        _beamDepthCtrl.text = widget.initialInputs!['beamDep']?.toString() ?? '';
        _beamLoadCtrl.text = widget.initialInputs!['beamLoad']?.toString() ?? '';
        _beamFck = widget.initialInputs!['beamFck']?.toString() ?? '20';
        _beamFy = widget.initialInputs!['beamFy']?.toString() ?? '415';
      } else if (_selectedSubCat == 'Column') {
        _colWidthCtrl.text = widget.initialInputs!['colWid']?.toString() ?? '';
        _colDepthCtrl.text = widget.initialInputs!['colDep']?.toString() ?? '';
        _colSteelCtrl.text = widget.initialInputs!['colSteel']?.toString() ?? '';
        _colLoadCtrl.text = widget.initialInputs!['colLoad']?.toString() ?? '';
        _colFck = widget.initialInputs!['colFck']?.toString() ?? '20';
      } else if (_selectedSubCat == 'Load') {
        _loadLenCtrl.text = widget.initialInputs!['loadLen']?.toString() ?? '';
        _loadHtCtrl.text = widget.initialInputs!['loadHt']?.toString() ?? '';
        _loadThickCtrl.text = widget.initialInputs!['loadThick']?.toString() ?? '';
        _loadStrCtrl.text = widget.initialInputs!['loadStr']?.toString() ?? '';
        _loadAppCtrl.text = widget.initialInputs!['loadApp']?.toString() ?? '';
      } else if (_selectedSubCat == 'Staircase') {
        _stairHtCtrl.text = widget.initialInputs!['stairHt']?.toString() ?? '';
        _stairRiseCtrl.text = widget.initialInputs!['stairRise']?.toString() ?? '';
        _stairTreadCtrl.text = widget.initialInputs!['stairTread']?.toString() ?? '';
        _stairWidCtrl.text = widget.initialInputs!['stairWid']?.toString() ?? '';
      }
    } else {
      _beamSpanCtrl.text = ''; _beamWidthCtrl.text = ''; _beamDepthCtrl.text = ''; _beamLoadCtrl.text = '';
      _colWidthCtrl.text = ''; _colDepthCtrl.text = ''; _colSteelCtrl.text = ''; _colLoadCtrl.text = '';
      _loadLenCtrl.text = ''; _loadHtCtrl.text = ''; _loadThickCtrl.text = ''; _loadStrCtrl.text = ''; _loadAppCtrl.text = '';
      _stairHtCtrl.text = ''; _stairRiseCtrl.text = ''; _stairTreadCtrl.text = ''; _stairWidCtrl.text = '';
    }
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

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_struct_cat', _selectedSubCat);
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
        category: 'Structural - Beam',
        title: 'Beam: ${res['safe'] ? "Safe" : "Unsafe"} (Mu: ${res['Mu']})',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Beam',
          'beamSpan': span,
          'beamWid': w,
          'beamDep': d,
          'beamLoad': load,
          'beamFck': _beamFck,
          'beamFy': _beamFy,
        },
        results: {
          'mainTitle': 'Status',
          'mainValue': res['safe'] ? "Safe" : "Unsafe",
          'formula': 'Mu: ${res['Mu']} kN·m',
          'materials': [
            {'label': 'Limiting Mu,lim', 'value': '${res['Mulim']} kN·m'},
            {'label': 'Slenderness (L/d)', 'value': '${res['slenderness']}'},
          ],
        },
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

      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Structural - Column',
        title: 'Column: ${res['safe'] ? "Safe" : "Unsafe"}',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Column',
          'colWid': w,
          'colDep': d,
          'colSteel': steel,
          'colLoad': load,
          'colFck': _colFck,
        },
        results: {
          'mainTitle': 'Status',
          'mainValue': res['safe'] ? "Safe" : "Unsafe",
          'formula': 'Capacity: ${res['capacity']} kN',
          'materials': [
            {'label': 'Gross Area', 'value': '${res['grossArea']} cm²'},
            {'label': 'Steel Area', 'value': '${res['steelArea']} mm²'},
          ],
        },
      );
      CalcHistoryService.save(item);

    } else if (_selectedSubCat == 'Load') {
      final len = double.tryParse(_loadLenCtrl.text) ?? 0;
      final ht = double.tryParse(_loadHtCtrl.text) ?? 0;
      final thick = double.tryParse(_loadThickCtrl.text) ?? 0;
      final str = double.tryParse(_loadStrCtrl.text) ?? 0;
      final app = double.tryParse(_loadAppCtrl.text) ?? 0;

      if (len <= 0 || ht <= 0 || thick <= 0 || str <= 0 || app <= 0) return;

      res = LoadBearingFormulas.calculate(lengthM: len, heightM: ht, thicknessMm: thick, brickStrengthMPa: str, appliedKNm: app);
      subtitle = 'Wall: ${len}x${ht}m | ${thick}mm thk';
      
      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Structural - Wall',
        title: 'Wall: ${res['safe'] ? "Safe" : "Unsafe"}',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Load',
          'loadLen': len,
          'loadHt': ht,
          'loadThick': thick,
          'loadStr': str,
          'loadApp': app,
        },
        results: {
          'mainTitle': 'Status',
          'mainValue': res['safe'] ? "Safe" : "Unsafe",
          'formula': 'Cap: ${res['capacity']} kN/m',
          'materials': [
            {'label': 'Slenderness Ratio', 'value': '${res['sr']}'},
            {'label': 'Mod Factor ks', 'value': '${res['ks']}'},
          ],
        },
      );
      CalcHistoryService.save(item);

    } else {
      final ht = double.tryParse(_stairHtCtrl.text) ?? 0;
      final r = double.tryParse(_stairRiseCtrl.text) ?? 0;
      final t = double.tryParse(_stairTreadCtrl.text) ?? 0;
      final w = double.tryParse(_stairWidCtrl.text) ?? 0;

      if (ht <= 0 || r <= 0 || t <= 0 || w <= 0) return;

      res = StaircaseFormulas.calculate(heightFt: ht, riserIn: r, treadIn: t, widthFt: w);
      subtitle = 'Stair: ht ${ht}ft | Rise: ${r}in | Tread: ${t}in';
      
      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Structural - Stair',
        title: 'Stairs: ${res['risers']} Risers',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Staircase',
          'stairHt': ht,
          'stairRise': r,
          'stairTread': t,
          'stairWid': w,
        },
        results: {
          'mainTitle': 'Treads/Risers',
          'mainValue': '${res['risers']} Risers',
          'formula': '${res['treads']} Treads',
          'materials': [
            {'label': 'Actual Riser', 'value': '${res['actualRiser']} in'},
            {'label': 'Going Distance', 'value': '${res['goingFt']} ft'},
          ],
        },
      );
      CalcHistoryService.save(item);
    }

    setState(() => _result = res);
  }

  void _reset() {
    setState(() {
      _beamSpanCtrl.clear(); _beamWidthCtrl.clear(); _beamDepthCtrl.clear(); _beamLoadCtrl.clear();
      _colWidthCtrl.clear(); _colDepthCtrl.clear(); _colSteelCtrl.clear(); _colLoadCtrl.clear();
      _loadLenCtrl.clear(); _loadHtCtrl.clear(); _loadThickCtrl.clear(); _loadStrCtrl.clear(); _loadAppCtrl.clear();
      _stairHtCtrl.clear(); _stairRiseCtrl.clear(); _stairTreadCtrl.clear(); _stairWidCtrl.clear();
      _beamFck = '20'; _beamFy = '415'; _colFck = '20';
      _result = null;
    });
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
    if (_result == null) {
      if (_selectedSubCat == 'Beam') {
        return const CalcGuideCard(title: 'BEAM ANALYSIS', steps: ['Enter beam span and section details.', 'Select concrete grade and steel type.', 'Calculate limit state moment capacity.'], formula: 'Mu = 0.87 × fy × Ast × d (Limit State)');
      } else if (_selectedSubCat == 'Column') {
        return const CalcGuideCard(title: 'COLUMN ANALYSIS', steps: ['Enter column section details.', 'Provide steel % and axial load.', 'Checks safe axial load capacity.'], formula: 'Pu = 0.4×fck×Ac + 0.67×fy×Asc');
      } else if (_selectedSubCat == 'Load') {
        return const CalcGuideCard(title: 'WALL ANALYSIS', steps: ['Enter wall length, height and thickness.', 'Provide brick compressive strength.', 'Verifies load bearing capacity.'], formula: 'Stress ≤ Allowable Bearing');
      } else {
        return const CalcGuideCard(title: 'STAIRCASE ANALYSIS', steps: ['Enter total floor height.', 'Provide desired riser and tread.', 'Calculates total steps required.'], formula: 'Risers = Height / Riser Height');
      }
    }

    if (_selectedSubCat == 'Beam') {
      final safe = _result!['safe'] as bool;
      return Column(
        children: [
          CalcResultHeader(
            title: 'Design Status',
            value: safe ? "Safe" : "Unsafe",
            formula: 'Capacity: ${_result!['Mulim']} kN·m',
            isWarning: !safe,
            warningText: safe ? null : 'Overstressed by ${_result!['utilisationPct']}%. Min depth: ${_result!['minDepthNeeded']}mm',
          ),
          UtilisationBar(utilisation: _result!['ratio'] as double),
          const SizedBox(height: 16),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Factored moment Mu', '${_result!['Mu']} kN·m'),
              CalcMaterialRow('Limiting Mu,lim', '${_result!['Mulim']} kN·m'),
              CalcMaterialRow('Slenderness (L/d)', '${_result!['slenderness']}'),
            ],
          ),
          CalcActionRow(onRecalculate: _calculate, onReset: _reset),
          const SizedBox(height: 24),
        ],
      );
    } else if (_selectedSubCat == 'Column') {
      final safe = _result!['safe'] as bool;
      return Column(
        children: [
          CalcResultHeader(
            title: 'Design Status',
            value: safe ? "Safe" : "Unsafe",
            formula: 'Capacity: ${_result!['capacity']} kN',
            isWarning: !safe,
            warningText: safe ? null : 'Section inadequate. Increase section size or steel %.',
          ),
          UtilisationBar(utilisation: _result!['utilisation'] as double),
          const SizedBox(height: 16),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Axial Capacity', '${_result!['capacity']} kN'),
              CalcMaterialRow('Gross Area', '${_result!['grossArea']} cm²'),
              CalcMaterialRow('Steel Area', '${_result!['steelArea']} mm²'),
            ],
          ),
          CalcActionRow(onRecalculate: _calculate, onReset: _reset),
          const SizedBox(height: 24),
        ],
      );
    } else if (_selectedSubCat == 'Load') {
      final safe = _result!['safe'] as bool;
      return Column(
        children: [
          CalcResultHeader(
            title: 'Design Status',
            value: safe ? "Safe" : "Unsafe",
            formula: 'Capacity: ${_result!['capacity']} kN/m',
            isWarning: !safe,
            warningText: safe ? null : 'Wall overstressed.',
          ),
          UtilisationBar(utilisation: _result!['utilisation'] as double),
          const SizedBox(height: 16),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Wall Capacity', '${_result!['capacity']} kN/m'),
              CalcMaterialRow('Slenderness Ratio', '${_result!['sr']}'),
              CalcMaterialRow('Mod factor ks', '${_result!['ks']}'),
            ],
          ),
          CalcActionRow(onRecalculate: _calculate, onReset: _reset),
          const SizedBox(height: 24),
        ],
      );
    } else {
      final safe = _result!['checkOK'] as bool;
      return Column(
        children: [
          CalcResultHeader(
            title: 'Treads/Risers',
            value: '${_result!['risers']} Risers',
            formula: '${_result!['treads']} Treads',
            isWarning: !safe,
            warningText: safe ? null : 'Falls outside standard comfort rule (2*R + T).',
          ),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Actual Riser', '${_result!['actualRiser']} in'),
              CalcMaterialRow('Going Distance', '${_result!['goingFt']} ft'),
              CalcMaterialRow('Rule Check', '${_result!['check']} (Target: 24-25.5)'),
            ],
          ),
          CalcActionRow(onRecalculate: _calculate, onReset: _reset),
          const SizedBox(height: 24),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('Structural', style: CalcTextStyles.screenTitle(context)),
        iconTheme: IconThemeData(color: CalcColors.textPrimary(context)),
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
                  CategoryChip(label: 'Beam', isActive: _selectedSubCat == 'Beam', onTap: () { setState(() { _selectedSubCat = 'Beam'; _result = null; }); }, activeColor: CalcColors.structural(context)),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Column', isActive: _selectedSubCat == 'Column', onTap: () { setState(() { _selectedSubCat = 'Column'; _result = null; }); }, activeColor: CalcColors.structural(context)),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Load bearing', isActive: _selectedSubCat == 'Load', onTap: () { setState(() { _selectedSubCat = 'Load'; _result = null; }); }, activeColor: CalcColors.structural(context)),
                  const SizedBox(width: 8),
                  CategoryChip(label: 'Staircase', isActive: _selectedSubCat == 'Staircase', onTap: () { setState(() { _selectedSubCat = 'Staircase'; _result = null; }); }, activeColor: CalcColors.structural(context)),
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
            CalcButton(label: 'CALCULATE', color: CalcColors.structural(context), onPressed: _calculate),
            const SizedBox(height: 16),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
