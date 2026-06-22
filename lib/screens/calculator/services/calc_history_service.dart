import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calc_history_item.dart';

class CalcHistoryService {
  static const _key = 'calc_history';
  
  static Future<void> save(CalcHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.insert(0, item); // newest first
    if (list.length > 50) list.removeLast();
    final json = list.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(json));
  }

  static Future<List<CalcHistoryItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => CalcHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
