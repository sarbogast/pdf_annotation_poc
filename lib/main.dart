import 'package:flutter/material.dart';

import 'screens/pdf_annotation_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Annotation POC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PdfAnnotationScreen(),
    );
  }
}
