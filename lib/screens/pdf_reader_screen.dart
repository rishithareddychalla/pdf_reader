import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf_reader/screens/bookmarks_screen.dart';

class PDFReaderScreen extends StatefulWidget {
  final String? pdfPath;

  const PDFReaderScreen({super.key, this.pdfPath});

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
  bool _swipeHorizontal = false;
  double _zoomFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    if (widget.pdfPath != null) {
      _loadFile(widget.pdfPath!);
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final file = File(path);
      setState(() {
        _pdfFile = file;
        _pdfPathKey = 'bookmarks_${_pdfFile!.path.hashCode}';
        _currentPage = 0;
        _bookmarks = [];
      });
      await _loadBookmarks();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = _prefs.getBool('darkMode') ?? false;
      _swipeHorizontal = _prefs.getBool('swipeHorizontal') ?? false;
      _zoomFactor = _prefs.getDouble('zoomFactor') ?? 1.0;
    });
  }

  Future<void> _saveBookmarks() async {
    if (_pdfFile != null) {
      await _prefs.setString(_pdfPathKey, jsonEncode(_bookmarks));
    }
  }

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

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
    _saveBookmarks();
  }

  void _deleteBookmark(int page) {
    setState(() {
      _bookmarks.remove(page);
    });
    _saveBookmarks();
  }

  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor + 0.1).clamp(1.0, 5.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor - 0.1).clamp(1.0, 5.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfFile?.path.split('/').last ?? "PDF Reader"),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarks.contains(_currentPage)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookmarksScreen(
                    bookmarks: _bookmarks,
                    onBookmarkTapped: (page) {
                      _pdfController?.setPage(page);
                    },
                    onBookmarkDeleted: _deleteBookmark,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Share') {
                // Share functionality
              } else if (value == 'Rotate') {
                // Rotate functionality
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Share',
                child: Text('Share'),
              ),
              const PopupMenuItem<String>(
                value: 'Rotate',
                child: Text('Rotate'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFile == null
              ? const Center(child: Text("No PDF selected."))
              : PDFView(
                  filePath: _pdfFile!.path,
                  enableSwipe: true,
                  swipeHorizontal: _swipeHorizontal,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: _currentPage,
                  defaultZoomFactor: _zoomFactor,
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
                  nightMode: _isDarkMode,
                ),
      bottomNavigationBar: _pdfFile == null
          ? null
          : BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.zoom_out), onPressed: _zoomOut),
                    Expanded(
                      child: Slider(
                        value: _currentPage.toDouble(),
                        min: 0,
                        max: (_totalPages - 1).toDouble(),
                        onChanged: (value) {
                          _pdfController?.setPage(value.toInt());
                        },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.zoom_in), onPressed: _zoomIn),
                    Text("${_currentPage + 1}/$_totalPages"),
                  ],
                ),
              ),
            ),
    );
  }
}
