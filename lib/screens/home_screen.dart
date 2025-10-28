import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';
import 'package:pdf_reader/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> _recentFiles = [];
  Map<String, Map<String, dynamic>> _pdfMetadata = {};
  final Map<String, PdfController> _pdfControllers = {};
  bool _isLoading = false;
  late SharedPreferences _prefs;
  bool _showLastOpenedDate = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  @override
  void dispose() {
    for (final controller in _pdfControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Initialize SharedPreferences and load recent files
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _showLastOpenedDate = _prefs.getBool('showLastOpenedDate') ?? true;
    });

    // **LOAD RECENT FILES FROM PERSISTENT STORAGE**
    await _loadRecentFiles();

    // Load metadata for all recent files
    for (final file in _recentFiles) {
      await _loadPdfMetadata(File(file['path']!));
    }
  }

  /// Save recent files list to SharedPreferences
  Future<void> _saveRecentFiles() async {
    final recentFilesJson =
        _recentFiles.map((file) => jsonEncode(file)).toList();
    await _prefs.setStringList('recent_files', recentFilesJson);
  }

  /// Load recent files from SharedPreferences
  Future<void> _loadRecentFiles() async {
    final List<String>? savedFilesJson =
        _prefs.getStringList('recent_files');
    if (savedFilesJson != null && savedFilesJson.isNotEmpty) {
      final loadedFiles = savedFilesJson.map((json) {
        final fileData = jsonDecode(json);
        return {'path': fileData['path'], 'name': fileData['name']};
      }).toList();

      // Filter out files that no longer exist
      final existingFiles = loadedFiles.where((fileData) {
        final file = File(fileData['path']!);
        return file.existsSync();
      }).toList();

      setState(() {
        _recentFiles = existingFiles;
      });

      // If any files were removed, update SharedPreferences
      if (existingFiles.length != loadedFiles.length) {
        await _saveRecentFiles();
      }
    }
  }

  /// Update last opened date for a file
  Future<void> _updateLastOpenedDate(String filePath) async {
    final now = DateTime.now().toIso8601String();
    await _prefs.setString('last_opened_date_${filePath.hashCode}', now);

    // Update metadata
    setState(() {
      if (_pdfMetadata.containsKey(filePath)) {
        _pdfMetadata[filePath]!['lastOpenedDate'] = now;
      }
    });
  }

  Future<void> _loadPdfMetadata(File file) async {
    int pageCount = 0;
    String? lastOpenedDate;

    try {
      final controller = _pdfControllers.putIfAbsent(
        file.path,
        () => PdfController(document: PdfDocument.openFile(file.path)),
      );

      final doc = await controller.document;
      pageCount = doc.pagesCount;
      lastOpenedDate = _prefs.getString(
        'last_opened_date_${file.path.hashCode}',
      );
    } catch (e) {
      pageCount = 0;
      lastOpenedDate = null;
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Could not read metadata for ${file.path.split('/').last}')),
      //   );
      // }
      _pdfControllers.remove(file.path)?.dispose();
    }

    if (!mounted) return;
    setState(() {
      _pdfMetadata[file.path] = {
        'pageCount': pageCount,
        'lastOpenedDate': lastOpenedDate,
      };
    });
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setState(() {
          _isLoading = true;
        });

        // Update last opened date immediately
        await _updateLastOpenedDate(file.path);

        // load metadata
        await _loadPdfMetadata(file);

        // **UPDATE RECENT LIST AND SAVE**
        setState(() {
          final newFile = {
            'path': file.path,
            'name': file.path.split('/').last,
          };
          if (!_recentFiles.any((f) => f['path'] == file.path)) {
            _recentFiles.insert(0, newFile);
            if (_recentFiles.length > 10) {
              _recentFiles.removeLast();
            }
          } else {
            // Move to top if already exists
            final existingIndex = _recentFiles.indexWhere(
              (f) => f['path'] == file.path,
            );
            if (existingIndex > 0) {
              final movedFile = _recentFiles.removeAt(existingIndex);
              _recentFiles.insert(0, movedFile);
            }
          }
        });

        // **SAVE TO PERSISTENT STORAGE**
        await _saveRecentFiles();

        setState(() {
          _isLoading = false;
        });

        // open reader screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(
              pdfPath: file.path,
              pdfName: file.path.split('/').last,
            ),
          ),
        );

        // Update last opened date after reading
        await _updateLastOpenedDate(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking PDF: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(toggleTheme: widget.toggleTheme),
                ),
              );

              // If cache was cleared, reload data immediately
              if (result == true) {
                setState(() {
                  _recentFiles.clear();
                  _pdfMetadata.clear();
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Recent Files",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _recentFiles.isEmpty
                      ? const Center(child: Text("No recent files"))
                      : ListView.builder(
                          itemCount: _recentFiles.length,
                          itemBuilder: (context, index) {
                            final fileData = _recentFiles[index];
                            final filePath = fileData['path']!;
                            final fileName =
                                fileData['name'] ?? filePath.split('/').last;
                            final metadata = _pdfMetadata[filePath] ??
                                {'pageCount': 0, 'lastOpenedDate': null};
                            final pageCount = metadata['pageCount'];
                            final lastOpenedDate = metadata['lastOpenedDate'];
                            final pdfController = _pdfControllers[filePath];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: pdfController != null
                                    ? SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: FutureBuilder<PdfPageImage?>(
                                          future: pdfController.document.then(
                                            (doc) => doc
                                                .getPage(1)
                                                .then(
                                                  (page) => page.render(
                                                    width: 100.0,
                                                    height: 100.0,
                                                  ),
                                                ),
                                          ),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                    ConnectionState.done &&
                                                snapshot.hasData) {
                                              return Image.memory(
                                                snapshot.data!.bytes,
                                              );
                                            } else {
                                              return const Icon(
                                                Icons.picture_as_pdf,
                                                size: 40,
                                              );
                                            }
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.picture_as_pdf,
                                        size: 40,
                                      ),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("Page count: $pageCount"),
                                    if (_showLastOpenedDate &&
                                        lastOpenedDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Last opened: ${DateFormat.yMd().add_jm().format(DateTime.parse(lastOpenedDate))}",
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () async {
                                  // Update last opened date
                                  await _updateLastOpenedDate(filePath);

                                  // Move to top of recent list
                                  setState(() {
                                    if (index > 0) {
                                      final movedFile = _recentFiles.removeAt(
                                        index,
                                      );
                                      _recentFiles.insert(0, movedFile);
                                    }
                                  });

                                  // Save updated list
                                  await _saveRecentFiles();

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PDFReaderScreen(pdfPath: filePath),
                                    ),
                                  );

                                  // Refresh metadata after returning from reader
                                  await _loadPdfMetadata(File(filePath));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPDF,
        tooltip: 'Pick PDF',
        child: const Icon(Icons.add),
      ),
    );
  }
}
