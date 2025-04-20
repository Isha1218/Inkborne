import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class EpubUpload extends StatefulWidget {
  const EpubUpload({super.key});

  @override
  State<EpubUpload> createState() => _EpubUploadState();
}

class _EpubUploadState extends State<EpubUpload> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffE7D5BD),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.arrow_back)),
            ),
            Spacer(),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Upload EPUB',
                      style: GoogleFonts.lato(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff5D473A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      color: const Color(0xffF5ECE2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32.0, vertical: 24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.upload_file,
                                size: 60, color: Color(0xff5D473A)),
                            const SizedBox(height: 12),
                            Text(
                              'Choose an EPUB file to upload',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                color: Color(0xff5D473A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff8B6B5C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                _pickEpubFile();
                              },
                              child: Text(
                                'Browse Files',
                                style: GoogleFonts.lato(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Spacer()
          ],
        ),
      ),
    );
  }

  Future<void> _pickEpubFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result != null && result.files.single.path != null) {
      var snackBar = SnackBar(
          content: Text(
              'The EPUB has been successfully uploaded. You will be able to chat with the characters in approximately 10 minutes after we have finished processing the file'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      String? filePath = result.files.single.path;
      final uri = Uri.parse('http://192.168.0.23:5000/upload_epub');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', filePath!));
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await http.Response.fromStream(response);
        final json = jsonDecode(body.body);
        print(json['text']);
      }
    }
  }
}
