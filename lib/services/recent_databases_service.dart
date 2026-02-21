import 'package:shared_preferences/shared_preferences.dart';

class RecentDatabasesService {
  static const _key = 'recent_databases';
  static const _maxRecent = 5;

  final Future<SharedPreferences> _prefs;

  RecentDatabasesService() : _prefs = SharedPreferences.getInstance();

  Future<List<String>> getPaths() async {
    final prefs = await _prefs;
    return prefs.getStringList(_key) ?? [];
  }

  Future<List<String>> add(String path) async {
    final prefs = await _prefs;
    var paths = await getPaths();
    paths = [path, ...paths.where((e) => e != path)];
    if (paths.length > _maxRecent) paths = paths.sublist(0, _maxRecent);
    await prefs.setStringList(_key, paths);
    return paths;
  }

  Future<List<String>> remove(String path) async {
    final prefs = await _prefs;
    var paths = await getPaths();
    paths = paths.where((e) => e != path).toList();
    await prefs.setStringList(_key, paths);
    return paths;
  }
}
