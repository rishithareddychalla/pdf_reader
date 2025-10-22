import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  const SettingsScreen({super.key, required this.toggleTheme});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isDarkMode = false;
  bool _swipeHorizontal = false;
  double _zoomFactor = 1.0;
  bool _showLastOpenedDate = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = _prefs.getBool('darkMode') ?? false;
      _swipeHorizontal = _prefs.getBool('swipeHorizontal') ?? false;
      _zoomFactor = _prefs.getDouble('zoomFactor') ?? 1.0;
      _showLastOpenedDate = _prefs.getBool('showLastOpenedDate') ?? true;
    });
  }

  Future<void> _setSwipeHorizontal(bool value) async {
    setState(() {
      _swipeHorizontal = value;
    });
    await _prefs.setBool('swipeHorizontal', value);
  }

  Future<void> _setShowLastOpenedDate(bool value) async {
    setState(() {
      _showLastOpenedDate = value;
    });
    await _prefs.setBool('showLastOpenedDate', value);
  }

  void _clearCache() {
    // In a real app, you would clear cached files here.
    // For this example, we'll just show a snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (value) {
              widget.toggleTheme(value);
              setState(() {
                _isDarkMode = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Horizontal Scrolling'),
            value: _swipeHorizontal,
            onChanged: _setSwipeHorizontal,
          ),
          SwitchListTile(
            title: const Text('Show Last Opened Date'),
            value: _showLastOpenedDate,
            onChanged: _setShowLastOpenedDate,
          ),
          ListTile(
            title: const Text('Clear Cache'),
            trailing: const Icon(Icons.delete),
            onTap: _clearCache,
          ),
        ],
      ),
    );
  }
}
