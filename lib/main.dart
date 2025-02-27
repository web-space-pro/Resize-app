import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const UploadScreen(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

@override
State<UploadScreen> createState() => UploadScreenState();
}

class UploadScreenState extends State<UploadScreen> {
  List<File> originalFiles = [];
  List<File> processedFiles = [];

  String selectedResolution = "HD";
  String selectedCompression = "Standard";
  String selectedFormat = "JPG";

  // 📂 Выбор файлов
  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null && file.path!.isNotEmpty) {
            originalFiles.add(File(file.path!));
          }
        }
      });
    }
  }

  // 🗑 Удаление изображения
  void removeImage(int index) {
    setState(() {
      originalFiles.removeAt(index);
      if (processedFiles.length > index) {
        processedFiles.removeAt(index);
      }
    });
  }

// 🔄 Обработка изображений с улучшенным сглаживанием
Future<void> processImages() async {
  List<File> newProcessedFiles = [];

  for (File image in originalFiles) {
    final bytes = await image.readAsBytes();
    img.Image? decodedImage;

// Декодируем изображение
    if (image.path.toLowerCase().endsWith(".heic") || image.path.toLowerCase().endsWith(".heif")) {
      decodedImage = img.decodeJpg(await FlutterImageCompress.compressWithList(
        bytes,
        quality: 95,
      ));
    } else if (image.path.toLowerCase().endsWith(".gif")) {
      final gifDecoder = img.GifDecoder();
      decodedImage = gifDecoder.decode(bytes);
    } else {
      decodedImage = img.decodeImage(bytes);
    }

      if (decodedImage == null) {
      continue;
    }

// Обычные форматы
else {
  decodedImage = img.decodeImage(bytes);
}

    if (decodedImage == null) continue;

    int newWidth, newHeight;
bool isPortrait = decodedImage.height > decodedImage.width;
bool isSquare = decodedImage.height == decodedImage.width;

switch (selectedResolution) {
  case "SD": // Теперь 720px вместо 480px
    if (isSquare) {
      newWidth = 720;
      newHeight = 720;
    } else if (isPortrait) {
      newWidth = 720;
      newHeight = (decodedImage.height * (720 / decodedImage.width)).toInt();
    } else {
      newWidth = (decodedImage.width * (720 / decodedImage.height)).toInt();
      newHeight = 720;
    }
    break;
    
  case "HD": // Теперь 960px вместо 720px
    if (isSquare) {
      newWidth = 960;
      newHeight = 960;
    } else if (isPortrait) {
      newWidth = 960;
      newHeight = (decodedImage.height * (960 / decodedImage.width)).toInt();
    } else {
      newWidth = (decodedImage.width * (960 / decodedImage.height)).toInt();
      newHeight = 960;
    }
    break;

  case "FullHD": // Оставляем 1080px без изменений
  default:
    if (isSquare) {
      newWidth = 1080;
      newHeight = 1080;
    } else if (isPortrait) {
      newWidth = 1080;
      newHeight = (decodedImage.height * (1080 / decodedImage.width)).toInt();
    } else {
      newWidth = (decodedImage.width * (1920 / decodedImage.height)).toInt();
      newHeight = 1920;
    }
    break;
}

   // 📌 Улучшенное изменение размера с использованием сглаживания
    img.Image resizedImage = img.copyResize(
      decodedImage,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );

    // 📌 Выбираем степень сжатия
    int quality;
    switch (selectedCompression) {
      case "Min":
        quality = 90; // Максимальное качество, минимальное сжатие
        break;
      case "Standard":
        quality = 60; // Баланс
        break;
      case "Max":
      default:
        quality = 40; // Максимальное сжатие, минимальный размер
        break;
    }

    List<int> encodedImage;
    String extension;

    switch (selectedFormat) {
      case "PNG":
        encodedImage = img.encodePng(resizedImage, level: selectedCompression == "Max" ? 9 : 3);
        extension = "png";
        break;

      case "WEBP":
        try {
          encodedImage = await FlutterImageCompress.compressWithList(
            resizedImage.getBytes(),
            format: CompressFormat.webp,
            quality: quality,
          );
          extension = "webp";
        } catch (e) {
          encodedImage = img.encodeJpg(resizedImage, quality: quality);
          extension = "jpg";
        }
        break;

      case "JPG":
      default:
        encodedImage = img.encodeJpg(resizedImage, quality: quality);
        extension = "jpg";
        break;
    }

    final tempDir = await getTemporaryDirectory();
    final outputFile = File("${tempDir.path}/${image.uri.pathSegments.last}_processed.$extension");
    await outputFile.writeAsBytes(encodedImage);
    newProcessedFiles.add(outputFile);
  }

  setState(() {
    processedFiles = newProcessedFiles;
  });
}
// 📥 Сохранение одного файла
Future<void> saveFile(File file) async {
  String? outputPath = await FilePicker.platform.saveFile(
    dialogTitle: "Сохранить изображение",
    fileName: file.uri.pathSegments.last,
    type: FileType.custom,
    allowedExtensions: ['jpg', 'png', 'webp'],
  );

  if (outputPath != null) {
    await file.copy(outputPath);
  }
}

// 📥 Сохранить все обработанные файлы
Future<void> saveAllFiles() async {
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

  if (selectedDirectory != null) {
    for (var file in processedFiles) {
      String newPath = "$selectedDirectory/${file.uri.pathSegments.last}";
      await file.copy(newPath);
    }
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF2E2E2E),
    body: Column(
      children: [
        Expanded(
          child: DropTarget(
            onDragDone: (detail) {
              setState(() {
                for (final droppedFile in detail.files) {
                  if (droppedFile.path.isNotEmpty) {
                    originalFiles.add(File(droppedFile.path));
                  }
                }
              });
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_upload, color: Colors.lightBlue, size: 100),
                  const SizedBox(height: 16),
                  const Text(
                    'Перетащите изображение сюда',
                    style: TextStyle(color: Colors.lightBlue, fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: pickFiles,
                    child: const Text("Обзор"),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical, // Вертикальный скролл
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10), // Отступы по бокам
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10, // Отступы между строками
                              children: List.generate(
                                processedFiles.isEmpty ? originalFiles.length : processedFiles.length,
                                (index) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.file(
                                          processedFiles.isEmpty ? originalFiles[index] : processedFiles[index],
                                          width: 150,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      // 🔴 Кнопка удаления
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: GestureDetector(
                                          onTap: () => removeImage(index),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(5),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (processedFiles.isNotEmpty)
                                        Positioned(
                                          right: 5,
                                          bottom: 5,
                                          child: GestureDetector(
                                            onTap: () => saveFile(processedFiles[index]),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(5),
                                              child: const Icon(
                                                Icons.download,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
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
        ),
        if (originalFiles.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: selectedResolution,
                  dropdownColor: Colors.blue,
                  style: const TextStyle(color: Colors.white),
                  items: ["SD", "HD", "FullHD"]
                      .map((res) => DropdownMenuItem(value: res, child: Text(res)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedResolution = value!),
                ),
                DropdownButton<String>(
                  value: selectedCompression,
                  dropdownColor: Colors.blue,
                  style: const TextStyle(color: Colors.white),
                  items: ["Min", "Standard", "Max"]
                      .map((comp) => DropdownMenuItem(value: comp, child: Text(comp)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedCompression = value!),
                ),
                if (originalFiles.length > 5 || processedFiles.length > 5)
                  ElevatedButton(
                    onPressed: saveAllFiles,
                    child: const Text("Скачать все"),
                  ),
                ElevatedButton(
                  onPressed: processImages,
                  child: const Text("Start"),
                ),
                DropdownButton<String>(
                  value: selectedFormat,
                  dropdownColor: Colors.blue,
                  style: const TextStyle(color: Colors.white),
                  items: ["JPG", "PNG", "WEBP"]
                      .map((format) => DropdownMenuItem(value: format, child: Text(format)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedFormat = value!),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
}