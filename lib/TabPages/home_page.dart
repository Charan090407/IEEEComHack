import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoading = false;

  Future<void> uploadAndProcessPDF() async {
    try {
      setState(() => isLoading = true);

      // 1️⃣ Pick PDF
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'PDFs',
        extensions: ['pdf'],
      );

      final XFile? xFile =
      await openFile(acceptedTypeGroups: [typeGroup]);

      if (xFile == null) {
        setState(() => isLoading = false);
        return;
      }

      File file = File(xFile.path);

      // 2️⃣ Convert to Base64
      List<int> fileBytes = await file.readAsBytes();
      String base64File = base64Encode(fileBytes);

      if (base64File.length > 900000) {
        throw Exception("File too large for Firestore (Max ~1MB)");
      }

      // 3️⃣ Extract Text
      PdfDocument document = PdfDocument(inputBytes: fileBytes);
      PdfTextExtractor extractor = PdfTextExtractor(document);
      String rawText = extractor.extractText();
      document.dispose();

      // 4️⃣ Generate Do's & Don'ts
      List<String> sentences = rawText.split('.');

      List<String> dos = [];
      List<String> donts = [];

      for (var sentence in sentences) {
        String trimmed = sentence.trim();
        String s = trimmed.toLowerCase();

        if (s.contains('must') ||
            s.contains('should') ||
            s.contains('required')) {
          dos.add(trimmed);
        } else if (s.contains('prohibited') ||
            s.contains('not allowed') ||
            s.contains('avoid') ||
            s.contains(' not ')) {
          donts.add(trimmed);
        }
      }

      // 5️⃣ Save to Firestore
      await FirebaseFirestore.instance.collection('directives').add({
        'fileName': xFile.name,
        'fileBase64': base64File,
        'rawText': rawText,
        'dos': dos,
        'donts': donts,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => isLoading = false);

      // 6️⃣ Show Popup with Results
      showResultsDialog(dos, donts);

    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void showResultsDialog(List<String> dos, List<String> donts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Directive Summary"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "✅ Do's:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                ...dos.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text("• $d"),
                )),
                const SizedBox(height: 16),
                const Text(
                  "❌ Don'ts:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ...donts.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text("• $d"),
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text("Upload Directive PDF"),
          onPressed: uploadAndProcessPDF,
        ),
      ),
    );
  }
}
