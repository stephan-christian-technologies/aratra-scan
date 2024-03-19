import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Added image_cropper package
import 'package:excel/excel.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Aratra Scanner',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? imageFile;
  String? extractedText;
  TextRecognizer googleTextDetector = GoogleMlKit.vision.textRecognizer();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aratra Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (imageFile != null)
              Image.file(imageFile!, width: 200, height: 200),
            ElevatedButton(
              onPressed: () async {
                final pickedFile =
                    await ImagePicker().pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  CroppedFile? croppedFile = await _cropImage(File(pickedFile.path)); // Crop the image
                  if (croppedFile != null) {
                    imageFile = File(croppedFile.path);
                    extractedText = await extractTextFromImage(imageFile!);
                    setState(() {});
                  }
                }
              },
              child: const Text('Prendre une photo'),
            ),
            if (extractedText != null) Text(extractedText!),
            ElevatedButton(
              onPressed: () async {
                if (extractedText != null) {
                  await saveTextToExcel(extractedText!);
                }
              },
              child: const Text('Enregistrer dans Excel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> extractTextFromImage(File imageFile) async {
    if (await hasInternetConnection()) {
      // **Google ML Kit**
      extractedText = await recognizeTextsWithGoogle(imageFile);
      Logger().i(extractedText);
      return extractedText;
    } else {
      // **Tesseract OCR**
      String text = await recognizeTextsWithTesseract(imageFile);
      return text;
    }
  }

  Future<void> saveTextToExcel(String extractedText) async {
    // Implémentez l'enregistrement du texte dans un fichier Excel
    // Vous pouvez utiliser le package `excel`
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue(extractedText)]);
    // Vous devez enregistrer le fichier Excel sur le périphérique de l'utilisateur
  }

  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      } else {
        return false;
      }
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<String> recognizeTextsWithGoogle(File imageFile) async {
    isLoading = true;
    final inputImage = InputImage.fromFilePath(imageFile.path);
    String extractedText = "";

    showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    // Finding text String(s)
    final text = await googleTextDetector.processImage(inputImage);
    for (TextBlock block in text.blocks) {
      for (TextLine line in block.lines) {
        if (kDebugMode) {
          print('text: ${line.text}');
        }
        extractedText += "${line.text}\n";
      }
    }
    isLoading = false;
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    return extractedText;
  }

  Future<String> recognizeTextsWithTesseract(File imageFile) async {
    showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    String text = await FlutterTesseractOcr.extractText(
      imageFile.path,
      language: 'fra+eng',
    );
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    return text;
  }

  Future<CroppedFile?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9
      ],
    );
    return croppedFile;
  }
}
