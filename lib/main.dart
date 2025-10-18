import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader App',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100], // Subtle tint for light mode
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[850], // Subtle tint for dark mode
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system, // Default to system theme
      home: const PDFReaderScreen(),
    );
  }
}

class PDFReaderScreen extends StatefulWidget {
  const PDFReaderScreen({super.key});

  @override
  _PDFReaderScreenState createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  File? _pdfFile;
  PDFViewController? _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  List<int> _bookmarks = [];
  late SharedPreferences _prefs;
  String _pdfPathKey = 'bookmarks_';
  final TextEditingController _pageInputController = TextEditingController();
  bool _isDarkMode = false;
  bool _swipeHorizontal = false; // Toggle between vertical/horizontal scrolling

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved bookmarks and theme preference
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = _prefs.getBool('darkMode') ?? false;
    });
  }

  // Save bookmarks for the current PDF
  Future<void> _saveBookmarks() async {
    if (_pdfFile != null) {
      await _prefs.setString(_pdfPathKey, jsonEncode(_bookmarks));
    }
  }

  // Load bookmarks for the current PDF
  Future<void> _loadBookmarks() async {
    if (_pdfFile != null) {
      String? bookmarksJson = _prefs.getString(_pdfPathKey);
      if (bookmarksJson != null) {
        setState(() {
          _bookmarks = List<int>.from(jsonDecode(bookmarksJson));
        });
      }
    }
  }

  // Pick and load a PDF file
  Future<void> _pickPDF() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _pdfFile = File(result.files.single.path!);
          _pdfPathKey = 'bookmarks_${_pdfFile!.path.hashCode}';
          _currentPage = 0;
          _bookmarks = [];
        });
        await _loadBookmarks();
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
    }
  }

  // Toggle dark/light mode
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _prefs.setBool('darkMode', _isDarkMode);
    });
  }

  // Toggle scroll direction
  void _toggleScrollDirection() {
    setState(() {
      _swipeHorizontal = !_swipeHorizontal;
    });
  }

  // Add or remove bookmark
  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
      _saveBookmarks();
    });
  }

  // Jump to a specific page
  void _jumpToPage() {
    int? page = int.tryParse(_pageInputController.text);
    if (page != null && page > 0 && page <= _totalPages) {
      _pdfController?.setPage(page - 1);
      setState(() {
        _currentPage = page - 1;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid page number')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Reader App'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: Icon(_swipeHorizontal ? Icons.swap_vert : Icons.swap_horiz),
            onPressed: _toggleScrollDirection,
            tooltip: 'Toggle Scroll Direction',
          ),
          if (_pdfFile != null)
            IconButton(
              icon: Icon(
                _bookmarks.contains(_currentPage)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              onPressed: _toggleBookmark,
              tooltip: 'Bookmark Page',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFile == null
          ? const Center(
              child: Text(
                'No PDF selected. Tap the button to pick a PDF.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: PDFView(
                    filePath: _pdfFile!.path,
                    enableSwipe: true,
                    swipeHorizontal: _swipeHorizontal,
                    autoSpacing: true,
                    pageFling: true,
                    pageSnap: true,
                    onRender: (pages) {
                      setState(() {
                        _totalPages = pages!;
                      });
                    },
                    onViewCreated: (PDFViewController controller) {
                      _pdfController = controller;
                    },
                    onPageChanged: (page, total) {
                      setState(() {
                        _currentPage = page!;
                      });
                    },
                    // defaultZoomFactor: 1.0,
                    nightMode: _isDarkMode,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page ${_currentPage + 1} of $_totalPages'),
                          if (_bookmarks.isNotEmpty)
                            DropdownButton<int>(
                              hint: const Text('Bookmarks'),
                              items: _bookmarks.map((page) {
                                return DropdownMenuItem<int>(
                                  value: page,
                                  child: Text('Page ${page + 1}'),
                                );
                              }).toList(),
                              onChanged: (page) {
                                if (page != null) {
                                  _pdfController?.setPage(page);
                                  setState(() {
                                    _currentPage = page;
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pageInputController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Go to page',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _jumpToPage,
                            child: const Text('Go'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPDF,
        tooltip: 'Pick PDF',
        child: const Icon(Icons.file_open),
      ),
    );
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    super.dispose();
  }
}
