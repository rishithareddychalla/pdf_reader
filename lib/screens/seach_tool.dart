import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          title: Text(
            'Search Result',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SizedBox(
            width: 328.0,
            child: Text(
              'No more occurrences found. Would you like to continue searching from the beginning?',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
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
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blueAccent,
                ),
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
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blueAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9F9F9);
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back, color: iconColor, size: 24),
            onPressed: () {
              widget.onTap?.call(SearchToolbarAction.cancelSearch);
              _isSearchInitiated = false;
              _editingController.clear();
              _pdfTextSearchResult.clear();
            },
          ),
          Expanded(
            child: TextFormField(
              style: TextStyle(color: textColor),
              enableInteractiveSelection: false,
              focusNode: focusNode,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              controller: _editingController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Find...',
                hintStyle: TextStyle(color: hintColor),
              ),
              onChanged: (text) => setState(() {}),
              onFieldSubmitted: (String value) {
                _isSearchInitiated = true;
                _pdfTextSearchResult = widget.controller!.searchText(
                  _editingController.text,
                );
                _pdfTextSearchResult.addListener(() {
                  if (super.mounted) setState(() {});
                  if (!_pdfTextSearchResult.hasResult &&
                      _pdfTextSearchResult.isSearchCompleted) {
                    widget.onTap?.call(SearchToolbarAction.noResultFound);
                  }
                });
              },
            ),
          ),
          if (_editingController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: iconColor, size: 22),
              onPressed: () {
                setState(() {
                  _editingController.clear();
                  _pdfTextSearchResult.clear();
                  widget.controller!.clearSelection();
                  _isSearchInitiated = false;
                  focusNode!.requestFocus();
                });
                widget.onTap?.call(SearchToolbarAction.clearText);
              },
              tooltip: widget.showTooltip ? 'Clear Text' : null,
            ),
          if (!_pdfTextSearchResult.isSearchCompleted && _isSearchInitiated)
            const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.only(right: 10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_pdfTextSearchResult.hasResult)
            Row(
              children: [
                Text(
                  '${_pdfTextSearchResult.currentInstanceIndex}',
                  style: TextStyle(color: textColor),
                ),
                Text(' of ', style: TextStyle(color: textColor)),
                Text(
                  '${_pdfTextSearchResult.totalInstanceCount}',
                  style: TextStyle(color: textColor),
                ),
                IconButton(
                  icon: Icon(Icons.navigate_before, color: iconColor, size: 24),
                  onPressed: () {
                    setState(() {
                      _pdfTextSearchResult.previousInstance();
                    });
                    widget.onTap?.call(SearchToolbarAction.previousInstance);
                  },
                  tooltip: widget.showTooltip ? 'Previous' : null,
                ),
                IconButton(
                  icon: Icon(Icons.navigate_next, color: iconColor, size: 24),
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
                    widget.onTap?.call(SearchToolbarAction.nextInstance);
                  },
                  tooltip: widget.showTooltip ? 'Next' : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
