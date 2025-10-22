import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';
import 'package:pdf_reader/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _recentFiles = [];
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

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _showLastOpenedDate = _prefs.getBool('showLastOpenedDate') ?? true;
    });
    // Optionally: load any persisted recent files paths if you stored them previously.
  }

  Future<void> _loadPdfMetadata(File file) async {
    int pageCount = 0;
    String? lastOpenedDate;

    try {
      final controller = _pdfControllers.putIfAbsent(
        file.path,
        () => PdfController(
          document: PdfDocument.openFile(file.path),
        ),
      );

      final doc = await controller.document;
      pageCount = doc.pagesCount;
      lastOpenedDate = _prefs.getString('last_opened_date_${file.path.hashCode}');
    } catch (e) {
      pageCount = 0;
      lastOpenedDate = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read metadata for ${file.path.split('/').last}')),
        );
      }
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

        // load metadata (await to show info immediately)
        await _loadPdfMetadata(file);

        // update recent list
        setState(() {
          if (!_recentFiles.any((p) => p.path == file.path)) {
            _recentFiles.insert(0, file);
            if (_recentFiles.length > 10) {
              _recentFiles.removeLast();
            }
          }
        });

        setState(() {
          _isLoading = false;
        });

        // open reader screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(pdfPath: file.path),
          ),
        );

        // refresh metadata after returning from reader
        await _loadPdfMetadata(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking PDF: $e')));
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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
                  child: Text("Recent Files",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _recentFiles.isEmpty
                      ? const Center(child: Text("No recent files"))
                      : ListView.builder(
                          itemCount: _recentFiles.length,
                          itemBuilder: (context, index) {
                            final file = _recentFiles[index];
                            final metadata = _pdfMetadata[file.path] ??
                                {'pageCount': 0, 'lastOpenedDate': null};
                            final pageCount = metadata['pageCount'];
                            final lastOpenedDate = metadata['lastOpenedDate'];
                            final pdfController = _pdfControllers[file.path];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: pdfController != null
                                    ? SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: FutureBuilder<PdfPageImage?>(
                                          future: pdfController.document.then((doc) => doc.getPage(1).then((page) => page.render(width: 100.0, height: 100.0))),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.done &&
                                                snapshot.hasData) {
                                              return Image.memory(snapshot.data!.bytes);
                                            } else {
                                              return const Icon(Icons.picture_as_pdf, size: 40);
                                            }
                                          },
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf, size: 40),
                                title: Text(
                                  file.path.split('/').last,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                                          "Last opened: ${DateFormat.yMd().add_jm().format(DateTime.parse(lastOpenedDate))}"),
                                    ]
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PDFReaderScreen(pdfPath: file.path),
                                    ),
                                  );
                                  // Refresh metadata after returning from reader
                                  await _loadPdfMetadata(file);
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
