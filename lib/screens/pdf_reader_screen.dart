import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_reader/screens/seach_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf_reader/screens/bookmarks_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';

class PDFReaderScreen extends StatefulWidget {
  final String? pdfPath;
  final String? pdfName;

  const PDFReaderScreen({
    super.key,
    this.pdfPath,
    this.pdfName,
  });

  @override
  _PDFReaderScreenState createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  File? _pdfFile;
  Uint8List? _pdfBytes;
  late PdfViewerController _pdfViewerController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  List<int> _bookmarks = [];
  late SharedPreferences _prefs;
  String _pdfPathKey = 'bookmarks_';
  bool _swipeHorizontal = false;
  late bool _showToolbar;
  late bool _showScrollHead;
  final GlobalKey<SearchToolbarState> _textSearchKey = GlobalKey();
  LocalHistoryEntry? _historyEntry;
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  @override
  void initState() {
    _showToolbar = false;
    _showScrollHead = true;
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initPreferences(); // Initialize SharedPreferences and load bookmarks
    if (widget.pdfPath != null) {
      _loadFile(widget.pdfPath!);
    }
  }

  void _ensureHistoryEntry() {
    if (_historyEntry == null) {
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null) {
        _historyEntry = LocalHistoryEntry(onRemove: _handleHistoryEntryRemoved);
        route.addLocalHistoryEntry(_historyEntry!);
      }
    }
  }

  void _handleHistoryEntryRemoved() {
    _textSearchKey.currentState?.clearSearch();
    setState(() {
      _showToolbar = false;
    });
    _historyEntry = null;
  }

  /// Initialize SharedPreferences and load preferences/bookmarks
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _swipeHorizontal = _prefs.getBool('swipeHorizontal') ?? false;
    });
    // Load bookmarks if pdfPath is available
    if (widget.pdfPath != null) {
      _pdfPathKey = 'bookmarks_${widget.pdfPath!.hashCode}';
      await _loadBookmarks();
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      setState(() {
        _pdfFile = file;
        _pdfBytes = bytes;
        _pdfPathKey = 'bookmarks_${file.path.hashCode}';
        _currentPage = 0;
        _bookmarks = [];
      });
      await _saveLastOpenedDate();
      await _loadBookmarks(); // Load bookmarks for this specific PDF
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLastOpenedDate() async {
    if (_pdfFile != null) {
      await _prefs.setString(
        'last_opened_date_${_pdfFile!.path.hashCode}',
        DateTime.now().toIso8601String(),
      );
    }
  }

  /// Save bookmarks to SharedPreferences
  Future<void> _saveBookmarks() async {
    if (_pdfFile != null) {
      await _prefs.setString(_pdfPathKey, jsonEncode(_bookmarks));
    }
  }

  /// Load bookmarks from SharedPreferences
  Future<void> _loadBookmarks() async {
    try {
      final String? bookmarksJson = _prefs.getString(_pdfPathKey);
      if (bookmarksJson != null) {
        setState(() {
          _bookmarks = List<int>.from(
            jsonDecode(bookmarksJson) as List<dynamic>,
          );
          _bookmarks.sort(); // Ensure bookmarks are sorted
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading bookmarks: $e')));
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
    _saveBookmarks(); // Save immediately after toggling
  }

  void _deleteBookmark(int page) {
    setState(() {
      _bookmarks.remove(page);
    });
    _saveBookmarks(); // Save immediately after deletion
  }

  void _zoomIn() {
    _pdfViewerController.zoomLevel += 0.2;
  }

  void _zoomOut() {
    _pdfViewerController.zoomLevel -= 0.2;
  }

  Future<void> _rotateDocument() async {
    if (_pdfBytes == null) return;
    final int currentPage = _pdfViewerController.pageNumber;
    setState(() {
      _isLoading = true;
    });
    final PdfDocument document = PdfDocument(inputBytes: _pdfBytes);
    for (int i = 0; i < document.pages.count; i++) {
      final PdfPage page = document.pages[i];
      final PdfPageRotateAngle currentAngle = page.rotation;
      switch (currentAngle) {
        case PdfPageRotateAngle.rotateAngle0:
          page.rotation = PdfPageRotateAngle.rotateAngle90;
          break;
        case PdfPageRotateAngle.rotateAngle90:
          page.rotation = PdfPageRotateAngle.rotateAngle180;
          break;
        case PdfPageRotateAngle.rotateAngle180:
          page.rotation = PdfPageRotateAngle.rotateAngle270;
          break;
        case PdfPageRotateAngle.rotateAngle270:
          page.rotation = PdfPageRotateAngle.rotateAngle0;
          break;
      }
    }
    final List<int> bytes = await document.save();
    document.dispose();
    setState(() {
      _pdfBytes = Uint8List.fromList(bytes);
      _isLoading = false;
      _pdfViewerController.jumpToPage(currentPage);
    });
  }

  Future<void> _sharePDF() async {
    if (_pdfFile != null) {
      await Share.shareXFiles([XFile(_pdfFile!.path)], text: 'Sharing PDF');
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdfView = _pdfBytes == null
        ? const Center(child: Text("No PDF selected."))
        : SfPdfViewer.memory(
            _pdfBytes!,
            controller: _pdfViewerController,
            onPageChanged: (details) {
              setState(() {
                _currentPage = details.newPageNumber - 1;
                _totalPages = _pdfViewerController.pageCount;
                // Save last opened page
                if (_pdfFile != null) {
                  _prefs.setInt(
                    'last_opened_page_${_pdfFile!.path.hashCode}',
                    _currentPage,
                  );
                }
              });
            },
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = _pdfViewerController.pageCount;
                final lastPage =
                    _prefs.getInt(
                      'last_opened_page_${_pdfFile!.path.hashCode}',
                    ) ??
                    0;
                _pdfViewerController.jumpToPage(lastPage + 1);
              });
            },
            scrollDirection: _swipeHorizontal
                ? PdfScrollDirection.horizontal
                : PdfScrollDirection.vertical,
            canShowScrollHead: _showScrollHead,
          );

    return Scaffold(
      appBar: _showToolbar
          ? AppBar(
              flexibleSpace: SafeArea(
                child: SearchToolbar(
                  key: _textSearchKey,
                  showTooltip: true,
                  controller: _pdfViewerController,
                  onTap: (SearchToolbarAction toolbarItem) async {
                    if (toolbarItem == SearchToolbarAction.cancelSearch) {
                      setState(() {
                        _showToolbar = false;
                        _showScrollHead = true;
                        if (Navigator.canPop(context)) {
                          Navigator.maybePop(context);
                        }
                      });
                    }
                    if (toolbarItem == SearchToolbarAction.noResultFound) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No results found.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFFAFAFA),
            )
          : AppBar(
              title: Text(widget.pdfName ??
                  (_pdfFile?.path.split('/').last ?? "PDF Reader")),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _showScrollHead = false;
                      _showToolbar = true;
                      _ensureHistoryEntry();
                    });
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
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C) // dark background
                      : const Color(0xFFF9F9F9), // light background
                  offset: const Offset(0, 50),
                  onSelected: (value) {
                    if (value == 'Share') {
                      _sharePDF();
                    } else if (value == 'Rotate') {
                      _rotateDocument();
                    } else if (value == 'Bookmarks') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookmarksScreen(
                            bookmarks: _bookmarks,
                            onBookmarkTapped: (page) {
                              _pdfViewerController.jumpToPage(page + 1);
                            },
                            onBookmarkDeleted: _deleteBookmark,
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.more_vert,
                    size: 26,
                    // color: Theme.of(context).iconTheme.color,
                  ),
                  itemBuilder: (BuildContext context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final textColor = isDark ? Colors.white : Colors.black87;
                    final secondaryColor = isDark
                        ? Colors.grey[400]
                        : Colors.grey[700];

                    return [
                      PopupMenuItem<String>(
                        value: 'Share',
                        child: Row(
                          children: [
                            Icon(
                              Icons.share_outlined,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blueAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Share PDF',
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Rotate',
                        child: Row(
                          children: [
                            Icon(
                              Icons.rotate_90_degrees_ccw,
                              color: isDark
                                  ? Colors.orange[300]
                                  : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Rotate Pages',
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Bookmarks',
                        child: Row(
                          children: [
                            Icon(
                              Icons.bookmark,
                              color: isDark
                                  ? Colors.pink[300]
                                  : Colors.pinkAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'View Bookmarks',
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: secondaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PDF Reader v1.0',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
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
                    IconButton(
                      icon: const Icon(Icons.zoom_out),
                      onPressed: _zoomOut,
                    ),
                    Expanded(
                      child: _totalPages > 1
                          ? Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: (_totalPages - 1).toDouble(),
                              onChanged: (value) {
                                _pdfViewerController.jumpToPage(
                                  value.toInt() + 1,
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in),
                      onPressed: _zoomIn,
                    ),
                    Text("${_currentPage + 1}/$_totalPages"),
                  ],
                ),
              ),
            ),
    );
  }
}
