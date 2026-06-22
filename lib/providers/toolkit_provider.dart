import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ToolkitProvider extends ChangeNotifier {
  static const String _favoritesKey = 'toolkit_favorites';
  static const String _recentsKey = 'toolkit_recents';
  static const int _maxRecents = 5;

  List<String> _favorites = [];
  List<String> _recents = [];
  bool _isInitialized = false;

  List<String> get favorites => _favorites;
  List<String> get recents => _recents;
  bool get isInitialized => _isInitialized;

  ToolkitProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    
    final favList = prefs.getStringList(_favoritesKey);
    if (favList != null) {
      _favorites = List<String>.from(favList);
    }
    
    final recList = prefs.getStringList(_recentsKey);
    if (recList != null) {
      _recents = List<String>.from(recList);
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(String route) async {
    if (_favorites.contains(route)) {
      _favorites.remove(route);
    } else {
      _favorites.add(route);
    }
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites);
  }

  bool isFavorite(String route) {
    return _favorites.contains(route);
  }

  Future<void> addToRecents(String route) async {
    _recents.remove(route);
    _recents.insert(0, route);
    
    if (_recents.length > _maxRecents) {
      _recents = _recents.sublist(0, _maxRecents);
    }
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentsKey, _recents);
  }
}
