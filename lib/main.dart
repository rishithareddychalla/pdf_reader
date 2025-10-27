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
    _intentSubscription = receive_intent.ReceiveIntent.receivedIntentStream.listen(
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

  void _navigateToReaderScreen(receive_intent.Intent intent) {
    //
    final path = intent.data;
    if (path != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PDFReaderScreen(
          ),
        ),
      );
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
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[850],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      home: HomeScreen(toggleTheme: _toggleTheme),
    );
  }
}
