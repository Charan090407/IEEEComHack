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

  // 🔹 BASIC TEXT CLEANING
  String cleanText(String text) {
    String cleaned = text;

    cleaned = cleaned
        .replaceAll("â€™", "'")
        .replaceAll("â€œ", '"')
        .replaceAll("â€", '"')
        .replaceAll("â€¢", "")
        .replaceAll("â€“", "-")
        .replaceAll("â€”", "-")
        .replaceAll("�", "");

    cleaned = cleaned.replaceAll(RegExp(r'[\uF000-\uF8FF]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[•●▪■□☐☑✓✔]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  // 🔹 PROFESSIONAL SENTENCE ENGINE
  List<String> cleanAndFormatSentences(String rawText) {
    List<String> splitData =
    rawText.split(RegExp(r'[.\n]'));

    List<String> finalSentences = [];

    for (String sentence in splitData) {
      String s = cleanText(sentence);

      if (s.isEmpty) continue;

      // Remove year patterns like 2026)
      if (RegExp(r'^\d{4}\)').hasMatch(s)) continue;

      // Remove standalone numbers
      if (RegExp(r'^\d+$').hasMatch(s)) continue;

      // Remove very short unclear fragments
      if (s.length < 15) continue;

      // Must contain meaningful directive words
      if (!RegExp(
          r'\b(must|should|required|prohibited|avoid|not allowed| not )\b',
          caseSensitive: false)
          .hasMatch(s)) continue;

      // Capitalize properly
      s = s[0].toUpperCase() + s.substring(1);

      // Ensure proper ending
      if (!s.endsWith('.')) {
        s = "$s.";
      }

      finalSentences.add(s);
    }

    return finalSentences;
  }

  Future<void> uploadAndProcessPDF() async {
    try {
      setState(() => isLoading = true);

      const XTypeGroup typeGroup =
      XTypeGroup(label: 'PDFs', extensions: ['pdf']);

      final XFile? xFile =
      await openFile(acceptedTypeGroups: [typeGroup]);

      if (xFile == null) {
        setState(() => isLoading = false);
        return;
      }

      File file = File(xFile.path);
      List<int> fileBytes = await file.readAsBytes();
      String base64File = base64Encode(fileBytes);

      if (base64File.length > 900000) {
        throw Exception("File too large for Firestore (Max ~1MB)");
      }

      // 🔹 Extract and Clean
      PdfDocument document =
      PdfDocument(inputBytes: fileBytes);
      PdfTextExtractor extractor =
      PdfTextExtractor(document);
      String rawText =
      cleanText(extractor.extractText());
      document.dispose();

      // 🔹 Smart Sentence Formatting
      List<String> formattedSentences =
      cleanAndFormatSentences(rawText);

      List<String> dos = [];
      List<String> donts = [];

      for (var sentence in formattedSentences) {
        String lower = sentence.toLowerCase();

        if (lower.contains('must') ||
            lower.contains('should') ||
            lower.contains('required')) {
          dos.add(sentence);
        } else if (lower.contains('prohibited') ||
            lower.contains('not allowed') ||
            lower.contains('avoid') ||
            lower.contains(' not ')) {
          donts.add(sentence);
        }
      }

      await FirebaseFirestore.instance
          .collection('directives')
          .add({
        'fileName': xFile.name,
        'fileBase64': base64File,
        'rawText': rawText,
        'dos': dos,
        'donts': donts,
        'createdAt':
        FieldValue.serverTimestamp(),
      });

      setState(() => isLoading = false);

      showResultsDialog(dos, donts);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // 🔹 POPUP (UNCHANGED)
  void showResultsDialog(
      List<String> dos,
      List<String> donts) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(28),
        ),
        elevation: 25,
        child: Container(
          padding:
          const EdgeInsets.all(24),
          constraints:
          const BoxConstraints(
              maxHeight: 650),
          child: Column(
            children: [
              const Text(
                "Directive Summary",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                  FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child:
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSection(
                        title: "Do’s",
                        items: dos,
                        color:
                        Colors.green,
                      ),
                      const SizedBox(
                          height: 25),
                      _buildSection(
                        title: "Don’ts",
                        items: donts,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child:
                ElevatedButton(
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    Colors.black,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                          30),
                    ),
                    padding:
                    const EdgeInsets
                        .symmetric(
                        vertical:
                        14),
                  ),
                  onPressed: () =>
                      Navigator.pop(
                          context),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                        fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
        color.withOpacity(0.07),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
            color: color
                .withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration:
                BoxDecoration(
                  color: color,
                  borderRadius:
                  BorderRadius
                      .circular(
                      10),
                ),
              ),
              const SizedBox(
                  width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight
                      .bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (items.isEmpty)
            const Text(
              "No items detected.",
              style: TextStyle(
                  color:
                  Colors.black54),
            ),
          ...items.map(
                (text) => Padding(
              padding:
              const EdgeInsets
                  .only(
                  bottom:
                  12),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    "• ",
                    style:
                    TextStyle(
                      fontSize:
                      18,
                      color:
                      color,
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                  Expanded(
                    child:
                    Text(
                      text,
                      style:
                      const TextStyle(
                        fontSize:
                        14.5,
                        height:
                        1.5,
                        letterSpacing:
                        0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 UI COMPLETELY UNCHANGED
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
        const BoxDecoration(
          gradient:
          LinearGradient(
            colors: [
              Color(
                  0xFF1E3C72),
              Color(
                  0xFF2A5298),
            ],
            begin:
            Alignment.topLeft,
            end: Alignment
                .bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child:
            AnimatedSwitcher(
              duration:
              const Duration(
                  milliseconds:
                  500),
              child: isLoading
                  ? Column(
                key:
                const ValueKey(
                    "loading"),
                mainAxisAlignment:
                MainAxisAlignment
                    .center,
                children:
                const [
                  SizedBox(
                    width:
                    70,
                    height:
                    70,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      5,
                      color:
                      Colors.white,
                    ),
                  ),
                  SizedBox(
                      height:
                      20),
                  Text(
                    "Processing Directive...",
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                      fontSize:
                      18,
                      fontWeight:
                      FontWeight
                          .w500,
                    ),
                  ),
                ],
              )
                  : _buildUploadUI(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadUI() {
    return TweenAnimationBuilder(
      key: const ValueKey("button"),
      duration:
      const Duration(milliseconds: 800),
      tween:
      Tween<double>(begin: 0.0, end: 1.0),
      builder:
          (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset:
            Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding:
        const EdgeInsets.all(30),
        margin:
        const EdgeInsets.symmetric(
            horizontal: 30),
        decoration: BoxDecoration(
          color:
          Colors.white.withOpacity(
              0.1),
          borderRadius:
          BorderRadius.circular(
              25),
          border: Border.all(
            color: Colors.white
                .withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              "Upload Public Directive",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                FontWeight.bold,
              ),
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              "Extract simplified Do’s and Don’ts from official government PDFs instantly.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap:
              uploadAndProcessPDF,
              child:
              AnimatedContainer(
                duration:
                const Duration(
                    milliseconds:
                    200),
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 35,
                  vertical: 15,
                ),
                decoration:
                BoxDecoration(
                  gradient:
                  const LinearGradient(
                    colors: [
                      Color(
                          0xFF00C9FF),
                      Color(
                          0xFF92FE9D),
                    ],
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                      30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors
                          .black
                          .withOpacity(
                          0.3),
                      blurRadius:
                      10,
                      offset:
                      const Offset(
                          0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize:
                  MainAxisSize
                      .min,
                  children: [
                    Icon(
                      Icons.upload_file,
                      color:
                      Colors.black,
                    ),
                    SizedBox(
                        width: 10),
                    Text(
                      "Upload PDF",
                      style:
                      TextStyle(
                        fontSize:
                        16,
                        fontWeight:
                        FontWeight
                            .bold,
                        color:
                        Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
