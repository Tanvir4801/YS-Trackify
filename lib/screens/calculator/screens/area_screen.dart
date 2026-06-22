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
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';

class AreaScreen extends StatefulWidget {
  const AreaScreen({super.key});

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  String _selectedSubCat = 'Tile'; // Tile, Plaster
  
  // Tile
  final _tileLenCtrl = TextEditingController(text: '15');
  final _tileWidCtrl = TextEditingController(text: '12');
  final _tileSqFtCtrl = TextEditingController(text: '4'); // e.g. 24x24 inch = 4 sq ft
  final _tileWastageCtrl = TextEditingController(text: '10');

  // Plaster
  final _plasAreaCtrl = TextEditingController(text: '100');
  final _plasThickCtrl = TextEditingController(text: '12');
  String _plasMix = '1:4';

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLastValues();
  }

  @override
  void dispose() {
    _saveLastValues();
    _tileLenCtrl.dispose();
    _tileWidCtrl.dispose();
    _tileSqFtCtrl.dispose();
    _tileWastageCtrl.dispose();
    _plasAreaCtrl.dispose();
    _plasThickCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSubCat = prefs.getString('calc_area_cat') ?? 'Tile';
      _tileLenCtrl.text = prefs.getString('calc_tile_len') ?? '15';
      _tileWidCtrl.text = prefs.getString('calc_tile_wid') ?? '12';
      _tileSqFtCtrl.text = prefs.getString('calc_tile_sqft') ?? '4';
      _tileWastageCtrl.text = prefs.getString('calc_tile_waste') ?? '10';
      _plasAreaCtrl.text = prefs.getString('calc_plas_area') ?? '100';
      _plasThickCtrl.text = prefs.getString('calc_plas_thick') ?? '12';
      _plasMix = prefs.getString('calc_plas_mix') ?? '1:4';
    });
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_area_cat', _selectedSubCat);
    await prefs.setString('calc_tile_len', _tileLenCtrl.text);
    await prefs.setString('calc_tile_wid', _tileWidCtrl.text);
    await prefs.setString('calc_tile_sqft', _tileSqFtCtrl.text);
    await prefs.setString('calc_tile_waste', _tileWastageCtrl.text);
    await prefs.setString('calc_plas_area', _plasAreaCtrl.text);
    await prefs.setString('calc_plas_thick', _plasThickCtrl.text);
    await prefs.setString('calc_plas_mix', _plasMix);
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    Map<String, dynamic> res;
    String subtitle = '';
    
    if (_selectedSubCat == 'Tile') {
      final len = double.tryParse(_tileLenCtrl.text) ?? 0;
      final wid = double.tryParse(_tileWidCtrl.text) ?? 0;
      final sqft = double.tryParse(_tileSqFtCtrl.text) ?? 0;
      final waste = double.tryParse(_tileWastageCtrl.text) ?? 0;

      if (len <= 0 || wid <= 0 || sqft <= 0) return;

      res = TileFormulas.calculate(lengthFt: len, widthFt: wid, tileSqFt: sqft, wastagePct: waste);
      subtitle = 'Area: ${len}x$wid ft | Tile: $sqft sqft';
      
      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Area Works',
        title: 'Tiles: ${res['grossTiles']}',
        subtitle: subtitle,
        timestamp: DateTime.now(),
      );
      CalcHistoryService.save(item);

    } else {
      final area = double.tryParse(_plasAreaCtrl.text) ?? 0;
      final thick = double.tryParse(_plasThickCtrl.text) ?? 0;

      if (area <= 0 || thick <= 0) return;

      res = PlasterFormulas.calculate(areaSqFt: area, thicknessMm: thick, mixRatio: _plasMix);
      subtitle = 'Area: $area sqft | Thick: ${thick}mm | Mix: $_plasMix';
      
      final item = CalcHistoryItem(
        id: const Uuid().v4(),
        category: 'Area Works',
        title: 'Cement: ${res['bags']} bags',
        subtitle: subtitle,
        timestamp: DateTime.now(),
      );
      CalcHistoryService.save(item);
    }

    setState(() => _result = res);
  }

  Widget _buildTileInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Room Len (ft)', controller: _tileLenCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Room Wid (ft)', controller: _tileWidCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Tile (sq ft)', controller: _tileSqFtCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Wastage (%)', controller: _tileWastageCtrl)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlasterInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: CalcInputField(label: 'Area (sq ft)', controller: _plasAreaCtrl)),
            const SizedBox(width: CalcDimens.fieldGap),
            Expanded(child: CalcInputField(label: 'Thick (mm)', controller: _plasThickCtrl)),
          ],
        ),
        const SizedBox(height: 16),
        CalcSelectField(
          label: 'Mix Ratio',
          value: _plasMix,
          items: const [
            DropdownMenuItem(value: '1:3', child: Text('Ceiling (1:3)')),
            DropdownMenuItem(value: '1:4', child: Text('Internal (1:4)')),
            DropdownMenuItem(value: '1:6', child: Text('External (1:6)')),
          ],
          onChanged: (v) { if (v != null) setState(() => _plasMix = v); },
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_result == null) return const SizedBox.shrink();

    if (_selectedSubCat == 'Tile') {
      return ResultCard(
        mainValue: '${_result!['grossTiles']} Tiles',
        mainLabel: 'Total Required (incl. wastage)',
        rows: [
          ResultRowData('Total Area', '${_result!['area']} sq ft'),
          ResultRowData('Net Tiles Needed', '${_result!['netTiles']}'),
        ],
        type: ResultType.neutral,
      );
    } else {
      return ResultCard(
        mainValue: '${_result!['bags']} Bags',
        mainLabel: 'Cement Required (${_result!['cementKg']} kg)',
        rows: [
          ResultRowData('Area in sq m', '${_result!['areaM2']} m²'),
          ResultRowData('Sand', '${_result!['sandCft']} cft'),
          ResultRowData('Water', '${_result!['waterL']} Liters'),
        ],
        type: ResultType.neutral,
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
        title: const Text('Area Works', style: CalcTextStyles.screenTitle),
        iconTheme: const IconThemeData(color: CalcColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryChip(label: 'Tiles', isActive: _selectedSubCat == 'Tile', onTap: () { setState(() { _selectedSubCat = 'Tile'; _result = null; }); }, activeColor: CalcColors.areaWorks),
                const SizedBox(width: 8),
                CategoryChip(label: 'Plaster', isActive: _selectedSubCat == 'Plaster', onTap: () { setState(() { _selectedSubCat = 'Plaster'; _result = null; }); }, activeColor: CalcColors.areaWorks),
              ],
            ),
            const SizedBox(height: 16),
            CalcCard(
              child: Padding(
                padding: const EdgeInsets.all(CalcDimens.cardPadding),
                child: Builder(builder: (context) {
                  if (_selectedSubCat == 'Tile') return _buildTileInputs();
                  return _buildPlasterInputs();
                }),
              ),
            ),
            const SizedBox(height: 8),
            CalcButton(label: 'CALCULATE', color: CalcColors.areaWorks, onPressed: _calculate),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
