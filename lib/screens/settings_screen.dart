import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

  Future<void> _setDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    await _prefs.setBool('darkMode', value);
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

  Future<void> _setZoomFactor(double value) async {
    setState(() {
      _zoomFactor = value;
    });
    await _prefs.setDouble('zoomFactor', value);
  }

  void _clearCache() {
    // In a real app, you would clear cached files here.
    // For this example, we'll just show a snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: _setDarkMode,
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
            title: Text('Default Zoom: ${_zoomFactor.toStringAsFixed(1)}'),
          ),
          Slider(
            value: _zoomFactor,
            min: 1.0,
            max: 5.0,
            divisions: 40,
            label: _zoomFactor.toStringAsFixed(1),
            onChanged: _setZoomFactor,
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
