import 'dart:math';

class ConcreteFormulas {
  static Map<String, dynamic> calculate({
    required double lengthFt,
    required double widthFt,
    required double depthFt,
    required String mixRatio,
  }) {
    final parts = mixRatio.split(':').map(double.parse).toList();
    final sum = parts.reduce((a, b) => a + b);
    final wetM3 = lengthFt * widthFt * depthFt * 0.0283168;
    final dryVol = wetM3 * 1.54;
    final cementM3 = dryVol * (parts[0] / sum);
    final cementBags = cementM3 / 0.03472;
    final sandM3 = dryVol * (parts[1] / sum);
    final aggM3 = dryVol * (parts[2] / sum);
    return {
      'wetM3': double.parse(wetM3.toStringAsFixed(3)),
      'cementBags': double.parse(cementBags.toStringAsFixed(1)),
      'cementKg': double.parse((cementBags * 50).toStringAsFixed(0)),
      'sandCft': double.parse((sandM3 * 35.315).toStringAsFixed(2)),
      'sandM3': double.parse(sandM3.toStringAsFixed(3)),
      'aggCft': double.parse((aggM3 * 35.315).toStringAsFixed(2)),
      'aggM3': double.parse(aggM3.toStringAsFixed(3)),
      'waterL': double.parse((cementBags * 25).toStringAsFixed(0)),
      'areaSqFt': double.parse((lengthFt * widthFt).toStringAsFixed(2)),
    };
  }
}

class BeamFormulas {
  static Map<String, dynamic> calculate({
    required double spanM,
    required double widthMm,
    required double depthMm,
    required double fck,
    required double fy,
    required double loadKNm,
  }) {
    final d = depthMm - 50; // effective depth
    final Mu = loadKNm * spanM * spanM / 8;
    final Mulim = 0.138 * fck * widthMm * d * d / 1e6;
    final ratio = Mu / Mulim;
    final slenderness = (spanM * 1000) / d;
    final slendOK = slenderness <= 20;
    final safe = Mu <= Mulim;
    final minDepth = sqrt(Mu * 1e6 / (0.138 * fck * widthMm));
    return {
      'Mu': double.parse(Mu.toStringAsFixed(2)),
      'Mulim': double.parse(Mulim.toStringAsFixed(2)),
      'ratio': double.parse(ratio.toStringAsFixed(3)),
      'utilisationPct': double.parse((ratio * 100).toStringAsFixed(1)),
      'slenderness': double.parse(slenderness.toStringAsFixed(1)),
      'slendOK': slendOK,
      'safe': safe,
      'effectiveDepth': d.toStringAsFixed(0),
      'minDepthNeeded': minDepth.ceil().toString(),
    };
  }
}

class ColumnFormulas {
  static Map<String, dynamic> calculate({
    required double widthMm,
    required double depthMm,
    required double fck,
    required double steelPct,
    required double appliedKN,
  }) {
    final Ag = widthMm * depthMm;
    final Asc = Ag * steelPct / 100;
    final Ac = Ag - Asc;
    final capacity = (0.4 * fck * Ac + 0.67 * 415 * Asc) / 1000;
    final safe = appliedKN <= capacity;
    final utilisation = appliedKN / capacity;
    return {
      'capacity': double.parse(capacity.toStringAsFixed(1)),
      'safe': safe,
      'utilisation': double.parse(utilisation.toStringAsFixed(3)),
      'utilisationPct': double.parse((utilisation * 100).toStringAsFixed(1)),
      'grossArea': double.parse((Ag / 1e4).toStringAsFixed(2)),
      'steelArea': double.parse(Asc.toStringAsFixed(0)),
      'status': safe ? 'Section adequate' : 'Increase section or steel %',
    };
  }
}

class LoadBearingFormulas {
  static Map<String, dynamic> calculate({
    required double lengthM,
    required double heightM,
    required double thicknessMm,
    required double brickStrengthMPa,
    required double appliedKNm,
  }) {
    final t = thicknessMm / 1000;
    final sr = heightM / t;
    double ks;
    if (sr <= 6) {
      ks = 1.0;
    } else if (sr <= 8) ks = 0.87;
    else if (sr <= 10) ks = 0.74;
    else if (sr <= 12) ks = 0.66;
    else ks = 0.5;
    final fm = brickStrengthMPa * 0.25;
    final capacity = ks * fm * t * 1000;
    final safe = appliedKNm <= capacity;
    final utilisation = appliedKNm / capacity;
    return {
      'capacity': double.parse(capacity.toStringAsFixed(1)),
      'safe': safe,
      'sr': double.parse(sr.toStringAsFixed(1)),
      'srOK': sr <= 12,
      'ks': ks,
      'fm': fm,
      'utilisation': double.parse(utilisation.toStringAsFixed(3)),
      'utilisationPct': double.parse((utilisation * 100).toStringAsFixed(1)),
    };
  }
}

class StaircaseFormulas {
  static Map<String, dynamic> calculate({
    required double heightFt,
    required double riserIn,
    required double treadIn,
    required double widthFt,
  }) {
    final htIn = heightFt * 12;
    final risers = (htIn / riserIn).ceil();
    final treads = risers - 1;
    final actualRiser = htIn / risers;
    final going = (treads * treadIn) / 12;
    final check = 2 * actualRiser + treadIn;
    final checkOK = check >= 24 && check <= 25.5;
    return {
      'risers': risers,
      'treads': treads,
      'actualRiser': double.parse(actualRiser.toStringAsFixed(2)),
      'goingFt': double.parse(going.toStringAsFixed(1)),
      'check': double.parse(check.toStringAsFixed(1)),
      'checkOK': checkOK,
    };
  }
}

class SteelFormulas {
  static Map<String, dynamic> calculate({
    required double diaMm,
    required double lengthM,
    required double nos,
  }) {
    final wpm = diaMm * diaMm / 162;
    final total = wpm * lengthM * nos;
    return {
      'wpm': double.parse(wpm.toStringAsFixed(3)),
      'totalLength': double.parse((lengthM * nos).toStringAsFixed(1)),
      'totalKg': double.parse(total.toStringAsFixed(1)),
      'bundles': double.parse((total / 45).toStringAsFixed(1)),
      'costEst': (total * 65).round(),
    };
  }
}

class TileFormulas {
  static Map<String, dynamic> calculate({
    required double lengthFt,
    required double widthFt,
    required double tileSqFt,
    required double wastagePct,
  }) {
    final area = lengthFt * widthFt;
    final net = area / tileSqFt;
    final gross = (net * (1 + wastagePct / 100)).ceil();
    return {
      'area': double.parse(area.toStringAsFixed(1)),
      'netTiles': net.ceil(),
      'grossTiles': gross,
    };
  }
}

class PlasterFormulas {
  static Map<String, dynamic> calculate({
    required double areaSqFt,
    required double thicknessMm,
    required String mixRatio,
  }) {
    final parts = mixRatio.split(':').map(double.parse).toList();
    final sum = parts[0] + parts[1];
    final areaM2 = areaSqFt * 0.0929;
    final wet = areaM2 * (thicknessMm / 1000);
    final dry = wet * 1.35;
    final bags = dry * (parts[0] / sum) / 0.03472;
    final sand = dry * (parts[1] / sum) * 35.315;
    return {
      'areaM2': double.parse(areaM2.toStringAsFixed(1)),
      'bags': double.parse(bags.toStringAsFixed(1)),
      'cementKg': double.parse((bags * 50).toStringAsFixed(0)),
      'sandCft': double.parse(sand.toStringAsFixed(1)),
      'waterL': double.parse((bags * 25).toStringAsFixed(0)),
    };
  }
}

class ExcavationFormulas {
  static Map<String, dynamic> calculate({
    required double lengthFt,
    required double widthFt,
    required double depthFt,
  }) {
    final cft = lengthFt * widthFt * depthFt;
    final m3 = cft * 0.0283168;
    final swell = m3 * 1.30;
    return {
      'cft': double.parse(cft.toStringAsFixed(1)),
      'm3': double.parse(m3.toStringAsFixed(2)),
      'swellM3': double.parse(swell.toStringAsFixed(2)),
      'trucks': (swell / 5).ceil(),
      'backfillM3': double.parse((m3 * 0.75).toStringAsFixed(2)),
    };
  }
}
