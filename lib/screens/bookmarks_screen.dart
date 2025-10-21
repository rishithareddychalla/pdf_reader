import 'package:flutter/material.dart';

class BookmarksScreen extends StatefulWidget {
  final List<int> bookmarks;
  final Function(int) onBookmarkTapped;
  final Function(int) onBookmarkDeleted;

  const BookmarksScreen({
    super.key,
    required this.bookmarks,
    required this.onBookmarkTapped,
    required this.onBookmarkDeleted,
  });

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: widget.bookmarks.isEmpty
          ? const Center(
              child: Text("No bookmarks yet."),
            )
          : ListView.builder(
              itemCount: widget.bookmarks.length,
              itemBuilder: (context, index) {
                final page = widget.bookmarks[index];
                return ListTile(
                  leading: const Icon(Icons.bookmark), // Placeholder for thumbnail
                  title: Text('Page ${page + 1}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        widget.onBookmarkDeleted(page);
                      });
                    },
                  ),
                  onTap: () {
                    widget.onBookmarkTapped(page);
                    Navigator.pop(context);
                  },
                );
              },
            ),
    );
  }
}
