// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_reader/main.dart';
import 'package:pdf_reader/screens/pdf_reader_screen.dart';

void main() {
  testWidgets('Page navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts without a PDF loaded.
    expect(find.text('No PDF selected. Tap the button to pick a PDF.'), findsOneWidget);

    // For the purpose of this test, we will assume a PDF is loaded and the total pages are 10.
    // In a real app, you would mock the file picker and PDF loading.
    // Here, we'll directly manipulate the state to simulate a loaded PDF.
    final state = tester.state(find.byType(PDFReaderScreen)) as _PDFReaderScreenState;
    state.setState(() {
      state.totalPages = 10;
    });
    await tester.pump();

    // Find the TextField for page input.
    final pageInputField = find.byType(TextField);
    expect(pageInputField, findsOneWidget);

    // Enter a page number into the TextField.
    await tester.enterText(pageInputField, '5');
    await tester.pump();

    // Find and tap the "Go" button.
    final goButton = find.widgetWithText(ElevatedButton, 'Go');
    expect(goButton, findsOneWidget);
    await tester.tap(goButton);
    await tester.pump();

    // Verify that the current page has changed.
    expect(find.text('Page 5 of 10'), findsOneWidget);
  });
}

// A stub for the _PDFReaderScreenState to access its properties
class _PDFReaderScreenState extends State<PDFReaderScreen> {
  int totalPages = 0;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
