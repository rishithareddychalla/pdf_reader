import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';
import 'package:pdf_reader/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_text/pdf_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _recentFiles = [];
  Map<String, Map<String, int>> _pdfMetadata = {};
  bool _isLoading = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadPdfMetadata(File file) async {
    int pageCount = 0;
    int lastPage = 0;

    try {
      // Use a timeout to prevent long waits on large/corrupt files
      PDFDoc doc = await PDFDoc.fromFile(file).timeout(const Duration(seconds: 5));
      pageCount = doc.length;
      lastPage = _prefs.getInt('last_page_${file.path.hashCode}') ?? 0;
    } catch (e) {
      pageCount = 0;
      lastPage = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read metadata for ${file.path.split('/').last}')),
      );
    }

    setState(() {
      _pdfMetadata[file.path] = {
        'pageCount': pageCount,
        'lastPage': lastPage,
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
        await _loadPdfMetadata(file); // Await metadata loading
        setState(() {
          if (!_recentFiles.any((p) => p.path == file.path)) {
            _recentFiles.insert(0, file);
            if (_recentFiles.length > 10) { // Store more recent files
              _recentFiles.removeLast();
            }
          }
        });
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(pdfPath: file.path),
          ),
        );
        // Refresh metadata after returning from reader
        await _loadPdfMetadata(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking PDF: $e')));
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
                            final metadata = _pdfMetadata[file.path] ?? {'pageCount': 0, 'lastPage': 0};
                            final pageCount = metadata['pageCount'];
                            final lastPage = metadata['lastPage'];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: const Icon(Icons.picture_as_pdf, size: 40),
                                title: Text(
                                  file.path.split('/').last,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("Page count: $pageCount"),
                                    const SizedBox(height: 2),
                                    Text("Last opened: $lastPage"),
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
