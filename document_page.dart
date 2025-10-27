import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'document_preview_page.dart';

class DocumentPage extends StatefulWidget {
  const DocumentPage({super.key});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  /// Each doc keeps name, size, type, and bytes (for preview).
  final List<Map<String, dynamic>> docs = [
    {
      "name": "Mou.pdf",
      "size": "23 MB",
      "type": "pdf",
      "bytes": null, // sample (no preview)
    },
    {
      "name": "Tmr_meeting.pdf",
      "size": "50 MB",
      "type": "pdf",
      "bytes": null, // sample (no preview)
    },
    {
      "name": "budgetsign.docx",
      "size": "50 MB",
      "type": "docx",
      "bytes": null, // sample (no preview)
    },
  ];

  // Pick a file and add to the list (with bytes for preview)
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true, // to get bytes for preview
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'zip'],
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    final ext = (f.extension ?? '').toLowerCase();
    final sizeMb = (f.size / (1024 * 1024)).toStringAsFixed(1);

    setState(() {
      docs.add({
        "name": f.name,
        "size": "$sizeMb MB",
        "type": ext,
        "bytes": f.bytes, // keep bytes for preview
      });
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Uploaded ${f.name}")),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Do you want to delete ${docs[index]['name']}?"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => docs.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text("Yes"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
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

  Color _getFileColor(String type) {
    switch (type) {
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

  void _openPreview(Map<String, dynamic> doc) {
    final String name = doc['name'] as String;
    final String size = doc['size'] as String;
    final String type = (doc['type'] as String?)?.toLowerCase() ?? '';
    final Uint8List? bytes = doc['bytes'] as Uint8List?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewPage(
          name: name,
          sizeLabel: size,
          type: type,
          bytes : bytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document List"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Add new files',
            onPressed: _pickFile,
          )
        ],
      ),
      body: ListView(
        children: [
          ...docs.asMap().entries.map((e) {
            final index = e.key;
            final doc = e.value;
            final type = (doc['type'] ?? '') as String;

            return ListTile(
              leading: InkWell(
                onTap: () => _openPreview(doc), // tap icon to preview
                child: Icon(_getFileIcon(type), color: _getFileColor(type)),
              ),
              title: Text(doc['name'] as String),
              subtitle: Text(doc['size'] as String),
              onTap: () => _openPreview(doc), // tap row to preview
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Edit ${doc['name']}")),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _confirmDelete(index),
                  ),
                ],
              ),
            );
          }),
          ListTile(
            title: const Text("Add new files"),
            trailing: const Icon(Icons.add),
            onTap: _pickFile,
          ),
        ],
      ),
    );
  }
}
