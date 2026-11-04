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
import '../widgets/calc_result_widgets.dart';

class AreaScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const AreaScreen({super.key, this.initialInputs});

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
    if (widget.initialInputs != null) {
      _selectedSubCat = widget.initialInputs!['subCat']?.toString() ?? 'Tile';
      _tileLenCtrl.text = widget.initialInputs!['tileLen']?.toString() ?? '';
      _tileWidCtrl.text = widget.initialInputs!['tileWid']?.toString() ?? '';
      _tileSqFtCtrl.text = widget.initialInputs!['tileSqFt']?.toString() ?? '';
      _tileWastageCtrl.text = widget.initialInputs!['tileWastage']?.toString() ?? '';
      _plasAreaCtrl.text = widget.initialInputs!['plasArea']?.toString() ?? '';
      _plasThickCtrl.text = widget.initialInputs!['plasThick']?.toString() ?? '';
      _plasMix = widget.initialInputs!['plasMix']?.toString() ?? '1:4';
    } else {
      _tileLenCtrl.text = '';
      _tileWidCtrl.text = '';
      _tileSqFtCtrl.text = '';
      _tileWastageCtrl.text = '';
      _plasAreaCtrl.text = '';
      _plasThickCtrl.text = '';
    }
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
        category: 'Area Works - Tile',
        title: 'Tiles: ${res['grossTiles']}',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Tile',
          'tileLen': len,
          'tileWid': wid,
          'tileSqFt': sqft,
          'tileWastage': waste,
        },
        results: {
          'mainTitle': 'Total Required',
          'mainValue': '${res['grossTiles']} Tiles',
          'formula': 'Incl. ${waste}% Wastage',
          'materials': [
            {'label': 'Total Area', 'value': '${res['area']} sq ft'},
            {'label': 'Net Tiles Needed', 'value': '${res['netTiles']}'},
          ],
        },
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
        category: 'Area Works - Plaster',
        title: 'Cement: ${res['bags']} bags',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        inputs: {
          'subCat': 'Plaster',
          'plasArea': area,
          'plasThick': thick,
          'plasMix': _plasMix,
        },
        results: {
          'mainTitle': 'Cement Required',
          'mainValue': '${res['bags']} Bags',
          'formula': '${res['cementKg']} kg total',
          'materials': [
            {'label': 'Area in sq m', 'value': '${res['areaM2']} m²'},
            {'label': 'Sand Needed', 'value': '${res['sandCft']} cft'},
            {'label': 'Water Needed', 'value': '${res['waterL']} Liters'},
          ],
        },
      );
      CalcHistoryService.save(item);
    }

    setState(() => _result = res);
  }

  void _reset() {
    setState(() {
      _tileLenCtrl.clear();
      _tileWidCtrl.clear();
      _tileSqFtCtrl.clear();
      _tileWastageCtrl.clear();
      _plasAreaCtrl.clear();
      _plasThickCtrl.clear();
      _plasMix = '1:4';
      _result = null;
    });
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
    if (_result == null) {
      if (_selectedSubCat == 'Tile') {
        return const CalcGuideCard(
          title: 'HOW TILE CALCULATION WORKS',
          steps: [
            'Enter the room dimensions.',
            'Enter the square footage of a single tile.',
            'Provide wastage percentage to calculate total tiles needed.',
          ],
          formula: 'Tiles = (Room Area / Tile Area) + Wastage',
        );
      } else {
        return const CalcGuideCard(
          title: 'HOW PLASTER WORKS',
          steps: [
            'Enter the total area to be plastered.',
            'Enter the plaster thickness in mm.',
            'Select the mix ratio to calculate cement and sand.',
          ],
          formula: 'Volume = Area × Thickness',
        );
      }
    }

    if (_selectedSubCat == 'Tile') {
      return Column(
        children: [
          CalcResultHeader(
            title: 'Total Required',
            value: '${_result!['grossTiles']} Tiles',
            formula: 'Incl. ${_tileWastageCtrl.text}% Wastage',
          ),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Total Area', '${_result!['area']} sq ft'),
              CalcMaterialRow('Net Tiles Needed', '${_result!['netTiles']}'),
            ],
          ),
          CalcDetailSection(
            details: {
              'Room Dimensions': '${_tileLenCtrl.text} × ${_tileWidCtrl.text} ft',
              'Tile Size': '${_tileSqFtCtrl.text} sq ft',
            },
          ),
          CalcActionRow(onRecalculate: _calculate, onReset: _reset),
          const SizedBox(height: 24),
        ],
      );
    } else {
      return Column(
        children: [
          CalcResultHeader(
            title: 'Cement Required',
            value: '${_result!['bags']} Bags',
            formula: '${_result!['cementKg']} kg total',
          ),
          CalcMaterialTable(
            rows: [
              CalcMaterialRow('Area in sq m', '${_result!['areaM2']} m²'),
              CalcMaterialRow('Sand Needed', '${_result!['sandCft']} cft'),
              CalcMaterialRow('Water Needed', '${_result!['waterL']} Liters'),
            ],
          ),
          CalcDetailSection(
            details: {
              'Plaster Area': '${_plasAreaCtrl.text} sq ft',
              'Thickness': '${_plasThickCtrl.text} mm',
              'Mix Ratio': _plasMix,
            },
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
        title: Text('Area Works', style: CalcTextStyles.screenTitle(context)),
        iconTheme: IconThemeData(color: CalcColors.textPrimary(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryChip(label: 'Tiles', isActive: _selectedSubCat == 'Tile', onTap: () { setState(() { _selectedSubCat = 'Tile'; _result = null; }); }, activeColor: CalcColors.areaWorks(context)),
                const SizedBox(width: 8),
                CategoryChip(label: 'Plaster', isActive: _selectedSubCat == 'Plaster', onTap: () { setState(() { _selectedSubCat = 'Plaster'; _result = null; }); }, activeColor: CalcColors.areaWorks(context)),
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
            CalcButton(label: 'CALCULATE', color: CalcColors.areaWorks(context), onPressed: _calculate),
            const SizedBox(height: 16),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
