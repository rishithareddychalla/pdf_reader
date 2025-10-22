import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf_reader/screens/bookmarks_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';

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
      await _saveLastOpenedDate();
      await _loadBookmarks();
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLastOpenedDate() async {
    if (_pdfFile != null) {
      await _prefs.setString('last_opened_date_${_pdfFile!.path.hashCode}', DateTime.now().toIso8601String());
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

  @override
  void dispose() {
    super.dispose();
  }

  void _deleteBookmark(int page) {
    setState(() {
      _bookmarks.remove(page);
    });
    _saveBookmarks();
  }

  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor + 0.2).clamp(1.0, 5.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor - 0.2).clamp(1.0, 5.0);
    });
  }

  Future<void> _sharePDF() async {
    if (_pdfFile != null) {
      await Share.shareXFiles([XFile(_pdfFile!.path)], text: 'Sharing PDF');
    }
  }

  Future<void> _showMetadata() async {
    if (_pdfFile == null) return;
    try {
      final Uint8List bytes = await _pdfFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Metadata'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Title: ${document.documentInformation.title ?? 'N/A'}'),
                Text('Author: ${document.documentInformation.author ?? 'N/A'}'),
                Text('Subject: ${document.documentInformation.subject ?? 'N/A'}'),
                Text('Keywords: ${document.documentInformation.keywords ?? 'N/A'}'),
                Text('Creator: ${document.documentInformation.creator ?? 'N/A'}'),
                Text('Producer: ${document.documentInformation.producer ?? 'N/A'}'),
                Text('Creation Date: ${document.documentInformation.creationDate ?? 'N/A'}'),
                Text('Modification Date: ${document.documentInformation.modificationDate ?? 'N/A'}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      document.dispose();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading metadata: $e')),
      );
    }
  }

  Future<String> _extractText() async {
    if (_pdfFile == null) return "";
    try {
      final Uint8List bytes = await _pdfFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      return "Error extracting text: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the PDFView whenever the zoom factor changes
    final pdfView = _pdfFile == null
        ? const Center(child: Text("No PDF selected."))
        : PDFView(
            key: ValueKey(_zoomFactor), // Use a key to force rebuild
            filePath: _pdfFile!.path,
            enableSwipe: true,
            swipeHorizontal: _swipeHorizontal,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: _currentPage,
            // defaultZoomFactor: _zoomFactor,
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
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfFile?.path.split('/').last ?? "PDF Reader"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final text = await _extractText();
              showSearch(
                context: context,
                delegate: PDFSearchDelegate(text, _isDarkMode),
              );
            },
          ),
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
                _sharePDF();
              } else if (value == 'Rotate') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rotation is not supported.')),
                );
              } else if (value == 'Metadata') {
                _showMetadata();
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
              const PopupMenuItem<String>(
                value: 'Metadata',
                child: Text('Metadata'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pdfView,
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
                      child: _totalPages > 1
                          ? Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: (_totalPages - 1).toDouble(),
                              onChanged: (value) {
                                _pdfController?.setPage(value.toInt());
                              },
                            )
                          : const SizedBox.shrink(),
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

class PDFSearchDelegate extends SearchDelegate {
  final String text;
  final bool isDarkMode;

  PDFSearchDelegate(this.text, this.isDarkMode);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: isDarkMode ? Colors.grey[850] : Colors.white,
      scaffoldBackgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text("Enter a search term."),
      );
    }
    final results = text.split('\n').where((line) => line.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(results[index]),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text("Enter a search term."),
      );
    }
    final suggestions = text.split('\n').where((line) => line.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestions[index]),
          onTap: () {
            query = suggestions[index];
            showResults(context);
          },
        );
      },
    );
  }
}