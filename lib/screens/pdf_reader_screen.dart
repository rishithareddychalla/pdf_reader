import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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

  @override
  void initState() {
    _showToolbar = false;
    _showScrollHead = true;
    super.initState();
    _pdfViewerController = PdfViewerController();
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
      final bytes = await file.readAsBytes();
      setState(() {
        _pdfFile = file;
        _pdfBytes = bytes;
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
      _swipeHorizontal = _prefs.getBool('swipeHorizontal') ?? false;
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
              });
            },
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = _pdfViewerController.pageCount;
                final lastPage = _prefs.getInt('last_opened_page_${_pdfFile!.path.hashCode}') ?? 0;
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
              title: Text(_pdfFile?.path.split('/').last ?? "PDF Reader"),
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
                IconButton(
                  icon: const Icon(Icons.bookmarks),
                  onPressed: () {
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
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'Share') {
                      _sharePDF();
                    } else if (value == 'Rotate') {
                      _rotateDocument();
                    } else if (value == 'Metadata') {
                      _showMetadata();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
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
                    IconButton(
                        icon: const Icon(Icons.zoom_out), onPressed: _zoomOut),
                    Expanded(
                      child: _totalPages > 1
                          ? Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: (_totalPages - 1).toDouble(),
                              onChanged: (value) {
                                _pdfViewerController
                                    .jumpToPage(value.toInt() + 1);
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    IconButton(
                        icon: const Icon(Icons.zoom_in), onPressed: _zoomIn),
                    Text("${_currentPage + 1}/$_totalPages"),
                  ],
                ),
              ),
            ),
    );
  }
}

enum SearchToolbarAction {
  cancelSearch,
  noResultFound,
  clearText,
  previousInstance,
  nextInstance,
}

typedef SearchTapCallback = void Function(SearchToolbarAction item);

class SearchToolbar extends StatefulWidget {
  const SearchToolbar({
    this.controller,
    this.onTap,
    this.showTooltip = true,
    Key? key,
  }) : super(key: key);

  final bool showTooltip;
  final PdfViewerController? controller;
  final SearchTapCallback? onTap;

  @override
  SearchToolbarState createState() => SearchToolbarState();
}

class SearchToolbarState extends State<SearchToolbar> {
  bool _isSearchInitiated = false;
  final TextEditingController _editingController = TextEditingController();
  PdfTextSearchResult _pdfTextSearchResult = PdfTextSearchResult();
  FocusNode? focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    focusNode?.requestFocus();
  }

  @override
  void dispose() {
    focusNode?.dispose();
    _pdfTextSearchResult.removeListener(() {});
    super.dispose();
  }

  void clearSearch() {
    _isSearchInitiated = false;
    _pdfTextSearchResult.clear();
  }

  void _showSearchAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(0),
          title: const Text('Search Result'),
          content: const SizedBox(
              width: 328.0,
              child: Text(
                  'No more occurrences found. Would you like to continue to search from the beginning?')),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _pdfTextSearchResult.nextInstance();
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'YES',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _pdfTextSearchResult.clear();
                  _editingController.clear();
                  _isSearchInitiated = false;
                  focusNode?.requestFocus();
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'NO',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
              size: 24,
            ),
            onPressed: () {
              widget.onTap?.call(SearchToolbarAction.cancelSearch);
              _isSearchInitiated = false;
              _editingController.clear();
              _pdfTextSearchResult.clear();
            },
          ),
        ),
        Flexible(
          child: TextFormField(
            style: Theme.of(context).textTheme.bodyMedium,
            enableInteractiveSelection: false,
            focusNode: focusNode,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            controller: _editingController,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Find...',
              hintStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
            onChanged: (text) {
              if (_editingController.text.isNotEmpty) {
                setState(() {});
              }
            },
            onFieldSubmitted: (String value) {
              _isSearchInitiated = true;
              _pdfTextSearchResult =
                  widget.controller!.searchText(_editingController.text);
              _pdfTextSearchResult.addListener(() {
                if (super.mounted) {
                  setState(() {});
                }
                if (!_pdfTextSearchResult.hasResult &&
                    _pdfTextSearchResult.isSearchCompleted) {
                  widget.onTap?.call(SearchToolbarAction.noResultFound);
                }
              });
            },
          ),
        ),
        Visibility(
          visible: _editingController.text.isNotEmpty,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: Icon(
                Icons.clear,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _editingController.clear();
                  _pdfTextSearchResult.clear();
                  widget.controller!.clearSelection();
                  _isSearchInitiated = false;
                  focusNode!.requestFocus();
                });
                widget.onTap!.call(SearchToolbarAction.clearText);
              },
              tooltip: widget.showTooltip ? 'Clear Text' : null,
            ),
          ),
        ),
        Visibility(
          visible:
              !_pdfTextSearchResult.isSearchCompleted && _isSearchInitiated,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        Visibility(
          visible: _pdfTextSearchResult.hasResult,
          child: Row(
            children: [
              Text(
                '${_pdfTextSearchResult.currentInstanceIndex}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                ' of ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${_pdfTextSearchResult.totalInstanceCount}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.navigate_before,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _pdfTextSearchResult.previousInstance();
                    });
                    widget.onTap!.call(SearchToolbarAction.previousInstance);
                  },
                  tooltip: widget.showTooltip ? 'Previous' : null,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.navigate_next,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_pdfTextSearchResult.currentInstanceIndex ==
                              _pdfTextSearchResult.totalInstanceCount &&
                          _pdfTextSearchResult.currentInstanceIndex != 0 &&
                          _pdfTextSearchResult.totalInstanceCount != 0 &&
                          _pdfTextSearchResult.isSearchCompleted) {
                        _showSearchAlertDialog(context);
                      } else {
                        widget.controller!.clearSelection();
                        _pdfTextSearchResult.nextInstance();
                      }
                    });
                    widget.onTap!.call(SearchToolbarAction.nextInstance);
                  },
                  tooltip: widget.showTooltip ? 'Next' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
