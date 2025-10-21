import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';
import 'package:pdf_reader/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _recentFiles = [];
  List<File> _allPdfs = [];
  List<File> _filteredPdfs = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
    _searchController.addListener(_filterPdfs);
  }

  Future<void> _loadPdfs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final pdfs = await _findPdfs(directory);
        setState(() {
          _allPdfs = pdfs;
          _filteredPdfs = pdfs;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<File>> _findPdfs(Directory dir) async {
    List<File> pdfs = [];
    await for (FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.pdf')) {
        pdfs.add(entity);
      }
    }
    return pdfs;
  }

  void _filterPdfs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPdfs = _allPdfs
          .where((pdf) => pdf.path.split('/').last.toLowerCase().contains(query))
          .toList();
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
          if (!_allPdfs.any((p) => p.path == file.path)) {
            _allPdfs.add(file);
            _filterPdfs();
          }
          if (!_recentFiles.any((p) => p.path == file.path)) {
            _recentFiles.insert(0, file);
            if (_recentFiles.length > 5) {
              _recentFiles.removeLast();
            }
          }
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderScreen(pdfPath: file.path),
          ),
        );
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
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search PDFs',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Recent Files",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 120,
                  child: _recentFiles.isEmpty
                      ? const Center(child: Text("No recent files"))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentFiles.length,
                          itemBuilder: (context, index) {
                            final file = _recentFiles[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PDFReaderScreen(pdfPath: file.path),
                                  ),
                                );
                              },
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    const Icon(Icons.picture_as_pdf, size: 50),
                                    const SizedBox(height: 8),
                                    Text(
                                      file.path.split('/').last,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("All PDFs",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _filteredPdfs.isEmpty
                      ? const Center(child: Text("No PDFs found."))
                      : ListView.builder(
                          itemCount: _filteredPdfs.length,
                          itemBuilder: (context, index) {
                            final file = _filteredPdfs[index];
                            return ListTile(
                              leading: const Icon(Icons.picture_as_pdf),
                              title: Text(file.path.split('/').last),
                              subtitle: Text("Path: ${file.path}"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PDFReaderScreen(pdfPath: file.path),
                                  ),
                                );
                              },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
