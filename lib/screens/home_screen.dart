
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Method channel for Android file handling
  static const platform = MethodChannel('pdf_reader/file_handler');

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
    try {
      _prefs = await SharedPreferences.getInstance();
      setState(() {
        _showLastOpenedDate = _prefs.getBool('showLastOpenedDate') ?? true;
      });

      // Load recent files from persistent storage
      await _loadRecentFiles();

      // Load metadata for all recent files
      for (final file in _recentFiles) {
        final filePath = file['path'];
        if (filePath != null && filePath.isNotEmpty) {
          await _loadPdfMetadata(File(filePath));
        }
      }
    } catch (e) {
      debugPrint('Error initializing preferences: $e');
    }
  }

  /// Save recent files list to SharedPreferences
  Future<void> _saveRecentFiles() async {
    try {
      final recentFilesJson =
          _recentFiles.map((file) => jsonEncode(file)).toList();
      await _prefs.setStringList('recent_files', recentFilesJson);
    } catch (e) {
      debugPrint('Error saving recent files: $e');
    }
  }

  /// Load recent files from SharedPreferences
  Future<void> _loadRecentFiles() async {
    try {
      final List<String>? savedFilesJson =
          _prefs.getStringList('recent_files');
      if (savedFilesJson != null && savedFilesJson.isNotEmpty) {
        final loadedFiles = <Map<String, String>>[];
        
        for (final json in savedFilesJson) {
          try {
            final fileData = jsonDecode(json) as Map<String, dynamic>;
            final path = fileData['path']?.toString();
            final name = fileData['name']?.toString();
            
            if (path != null && name != null) {
              loadedFiles.add({'path': path, 'name': name});
            }
          } catch (e) {
            debugPrint('Error parsing file data: $e');
            continue;
          }
        }

        // Filter out files that no longer exist
        final existingFiles = <Map<String, String>>[];
        for (final fileData in loadedFiles) {
          final filePath = fileData['path'];
          if (filePath != null) {
            final file = File(filePath);
            if (file.existsSync()) {
              existingFiles.add(fileData);
            }
          }
        }

        if (mounted) {
          setState(() {
            _recentFiles = existingFiles;
          });
        }

        // If any files were removed, update SharedPreferences
        if (existingFiles.length != loadedFiles.length) {
          await _saveRecentFiles();
        }
      }
    } catch (e) {
      debugPrint('Error loading recent files: $e');
    }
  }

  /// Update last opened date for a file
  Future<void> _updateLastOpenedDate(String filePath) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _prefs.setString('last_opened_date_${filePath.hashCode}', now);

      // Update metadata
      if (mounted) {
        setState(() {
          if (_pdfMetadata.containsKey(filePath)) {
            _pdfMetadata[filePath]!['lastOpenedDate'] = now;
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating last opened date: $e');
    }
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
      debugPrint('Error loading PDF metadata for ${file.path}: $e');
      pageCount = 0;
      lastOpenedDate = null;
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

  /// Handle content URI files (from external apps)
  Future<void> _handleContentUri(String contentUri, String destinationDir) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await platform.invokeMethod('copyContentUri', {
        'contentUri': contentUri,
        'destinationPath': destinationDir,
      }) as Map<String, dynamic>;

      if (result['success'] == true) {
        final fileName = result['fileName'] as String? ?? 'Unknown PDF';
        final file = File(destinationDir);
        
        // Update last opened date immediately
        await _updateLastOpenedDate(file.path);

        // Load metadata
        await _loadPdfMetadata(file);

        // Update recent list and save
        await _addToRecentFiles(file.path, fileName);

        if (mounted) {
          // Open reader screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFReaderScreen(
                pdfPath: file.path,
                pdfName: fileName,
              ),
            ),
          );

          // Update last opened date after reading
          await _updateLastOpenedDate(file.path);
        }
      } else {
        throw Exception('Failed to copy content URI file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error handling file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Add file to recent files list
  Future<void> _addToRecentFiles(String filePath, String fileName) async {
    try {
      if (mounted) {
        setState(() {
          final newFile = {
            'path': filePath,
            'name': fileName,
          };
          
          // Remove if already exists
          _recentFiles.removeWhere((f) => f['path'] == filePath);
          
          // Add to top
          _recentFiles.insert(0, newFile);
          
          // Keep only last 10 files
          if (_recentFiles.length > 10) {
            _recentFiles = _recentFiles.take(10).toList();
          }
        });
      }

      // Save to persistent storage
      await _saveRecentFiles();
    } catch (e) {
      debugPrint('Error adding to recent files: $e');
    }
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setState(() {
          _isLoading = true;
        });

        // Update last opened date immediately
        await _updateLastOpenedDate(file.path);

        // Load metadata
        await _loadPdfMetadata(file);

        // Update recent list and save
        await _addToRecentFiles(file.path, fileName);

        setState(() {
          _isLoading = false;
        });

        // Open reader screen
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFReaderScreen(
                pdfPath: file.path,
                pdfName: fileName,
              ),
            ),
          );

          // Update last opened date after reading
          await _updateLastOpenedDate(file.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRecentFile(int index) async {
    try {
      final fileData = _recentFiles[index];
      final filePath = fileData['path'];
      final fileName = fileData['name'];
      
      if (filePath == null || fileName == null) {
        throw Exception('Invalid file data');
      }

      // Check if file still exists
      final file = File(filePath);
      if (!file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File no longer exists')),
          );
        }
        
        // Remove from recent files
        setState(() {
          _recentFiles.removeAt(index);
        });
        await _saveRecentFiles();
        return;
      }

      // Update last opened date
      await _updateLastOpenedDate(filePath);

      // Move to top of recent list
      if (mounted) {
        setState(() {
          if (index > 0) {
            final movedFile = _recentFiles.removeAt(index);
            _recentFiles.insert(0, movedFile);
          }
        });
      }

      // Save updated list
      await _saveRecentFiles();

      // Open PDF reader
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(
              pdfPath: filePath,
              pdfName: fileName,
            ),
          ),
        );

        // Refresh metadata after returning from reader
        await _loadPdfMetadata(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
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
                
                // Dispose all controllers
                for (final controller in _pdfControllers.values) {
                  controller.dispose();
                }
                _pdfControllers.clear();
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
                            final filePath = fileData['path'];
                            final fileName = fileData['name'];
                            
                            if (filePath == null || fileName == null) {
                              return const SizedBox.shrink();
                            }
                            
                            final metadata = _pdfMetadata[filePath] ??
                                {'pageCount': 0, 'lastOpenedDate': null};
                            final pageCount = metadata['pageCount'] ?? 0;
                            final lastOpenedDate = metadata['lastOpenedDate'];
                            final pdfController = _pdfControllers[filePath];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: _buildThumbnail(pdfController),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                        "Last opened: ${_formatDate(lastOpenedDate)}",
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () => _openRecentFile(index),
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

  Widget _buildThumbnail(PdfController? pdfController) {
    return SizedBox(
      width: 50,
      height: 50,
      child: pdfController != null
          ? FutureBuilder<PdfPageImage?>(
              future: pdfController.document.then(
                (doc) => doc.getPage(1).then(
                  (page) => page.render(
                    width: 100.0,
                    height: 100.0,
                  ),
                ),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!.bytes,
                    fit: BoxFit.cover,
                  );
                } else {
                  return const Icon(
                    Icons.picture_as_pdf,
                    size: 40,
                  );
                }
              },
            )
          : const Icon(
              Icons.picture_as_pdf,
              size: 40,
            ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat.yMd().add_jm().format(date);
    } catch (e) {
      return 'Unknown';
    }
  }
}