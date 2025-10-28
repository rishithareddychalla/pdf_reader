import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf_reader/screens/home_screen.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';

import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.light;
  StreamSubscription? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _handleIntent();
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleIntent() async {
    // Handle initial intent
    final initialIntent = await receive_intent.ReceiveIntent.getInitialIntent();
    if (initialIntent != null) {
      _navigateToReaderScreen(initialIntent);
    }

    // Handle intents received while the app is running
    _intentSubscription = receive_intent.ReceiveIntent.receivedIntentStream
        .listen(
          (receive_intent.Intent? intent) {
            if (intent != null) {
              _navigateToReaderScreen(intent);
            }
          },
          onError: (err) {
            debugPrint('Error receiving intent: $err');
          },
        );
  }

  void _navigateToReaderScreen(
    receive_intent.Intent intent, {
    bool saveToRecents = true,
  }) {
    final path = intent.data;
    if (path != null) {
      if (saveToRecents) {
        _saveToRecentFiles(path);
      }
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PDFReaderScreen(pdfPath: path),
        ),
      );
    }
  }

  Future<void> _saveToRecentFiles(String path) async {
    _prefs = await SharedPreferences.getInstance();
    final List<String> recentFiles = _prefs.getStringList('recent_files') ?? [];
    if (!recentFiles.contains(path)) {
      recentFiles.insert(0, path);
      if (recentFiles.length > 10) {
        recentFiles.removeLast();
      }
      await _prefs.setStringList('recent_files', recentFiles);
    }
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final isDarkMode = _prefs.getBool('darkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _prefs.setBool('darkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PDF Reader App',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF5C6BC0), // soft indigo-blue
          secondary: const Color(0xFF90CAF9), // light sky blue
          surface: const Color(0xFFF8FAFC), // near-white background
          onSurface: Colors.black87,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF5C6BC0),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        cardColor: Colors.white,
        shadowColor: Colors.black12,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF7986CB), // soft indigo
          secondary: const Color(0xFF64B5F6), // calm blue
          surface: const Color(0xFF121212), // dark surface
          onSurface: Colors.white70,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2742),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF1C1F26),
        shadowColor: Colors.black54,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        useMaterial3: true,
      ),

      themeMode: _themeMode,
      home: HomeScreen(toggleTheme: _toggleTheme),
    );
  }
}
