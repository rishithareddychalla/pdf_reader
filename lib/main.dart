import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_reader/screens/home_screen.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<void> _navigateToReaderScreen(
    receive_intent.Intent intent, {
    bool saveToRecents = true,
  }) async {
    final path = intent.data;
    if (path != null) {
      String realPath = path;
      String? originalFileName;

      // Convert content:// URIs to real files
      if (path.startsWith("content://")) {
        try {
          // Extract the original filename from the content URI
          final platform = const MethodChannel('pdf_reader/file_handler');
          originalFileName =
              await platform.invokeMethod('getFileNameFromContentUri', {
            'contentUri': path,
          });

          final tempDir = await getTemporaryDirectory();
          final fileName =
              'shared_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final tempFile = File('${tempDir.path}/$fileName');

          // Use platform channel to copy content URI to temp file
          final result = await platform.invokeMethod('copyContentUri', {
            'contentUri': path,
            'destinationPath': tempFile.path,
          });

          if (result == true && await tempFile.exists()) {
            realPath = tempFile.path;
          } else {
            debugPrint("Failed to copy file from content URI.");
            return;
          }
        } catch (e) {
          debugPrint("Error handling content URI: $e");
          return;
        }
      }

      if (saveToRecents) {
        _saveToRecentFiles(
          realPath,
          originalFileName,
        );
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PDFReaderScreen(
            pdfPath: realPath,
            pdfName: originalFileName,
          ),
        ),
      );
    }
  }

  Future<void> _saveToRecentFiles(String path, String? name) async {
    _prefs = await SharedPreferences.getInstance();
    final List<String> recentFilesJson =
        _prefs.getStringList('recent_files') ?? [];
    final recentFiles = recentFilesJson.map((e) => jsonDecode(e)).toList();

    if (!recentFiles.any((file) => file['path'] == path)) {
      recentFiles.insert(0, {
        'path': path,
        'name': name ?? path.split('/').last,
      });
      if (recentFiles.length > 10) {
        recentFiles.removeLast();
      }
      await _prefs.setStringList(
        'recent_files',
        recentFiles.map((e) => jsonEncode(e)).toList(),
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
