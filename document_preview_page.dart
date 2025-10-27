import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentPreviewPage extends StatelessWidget {
  final String name;
  final String sizeLabel;
  final String type;      // 'pdf' | 'docx' | 'zip' | ...
  final Uint8List? bytes; // may be null for sample rows

  const DocumentPreviewPage({
    super.key,
    required this.name,
    required this.sizeLabel,
    required this.type,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    // Real PDF preview using bytes
    if (type == 'pdf' && bytes != null && bytes!.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Preview: $name")),
        body: SfPdfViewer.memory(bytes!),
      );
    }

    // Fallback info card for unsupported or sample items
    final icon = _iconFor(type);
    final color = _colorFor(type);

    return Scaffold(
      appBar: AppBar(title: Text("Preview: $name")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 72),
                  const SizedBox(height: 12),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(sizeLabel),
                  const SizedBox(height: 12),
                  Text(
                    type == 'pdf'
                        ? "This sample item has no bytes to preview."
                        : "Preview for .$type is not supported yet.\n"
                          "You can open it with an external app or convert to PDF.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'zip':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorFor(String t) {
    switch (t) {
      case 'pdf':
        return Colors.red;
      case 'docx':
        return Colors.blue;
      case 'zip':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
