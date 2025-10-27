import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

  void _clearCache(BuildContext context) async {
  try {
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/cache');
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }

    // Clear SharedPreferences
    await _prefs.clear();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully!')),
    );

    // Return to HomeScreen and indicate that cache was cleared
    Navigator.pop(context, true);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to clear cache: $e')),
    );
  }
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
            onTap: () => _clearCache(context),
          ),
        ],
      ),
    );
  }
}
