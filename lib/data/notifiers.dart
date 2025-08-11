import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);
ValueNotifier<bool> isDarkNotifier = ValueNotifier(true);
ValueNotifier<Map<String, List<double>>> facesNotifier = ValueNotifier({
});

Future<void> saveFaces(Map<String, List<double>> faces) async {
  final file = await _localFile;
  final jsonMap = faces.map((key, value) => MapEntry(key, value));
  final jsonString = jsonEncode(jsonMap);
  await file.writeAsString(jsonString);
}

Future<Map<String, List<double>>> loadFaces() async {
  try {
    final file = await _localFile;
    if (!(await file.exists())) return {};

    final jsonString = await file.readAsString();
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    final Map<String, List<double>> faces = jsonMap.map((key, value) {
      final List<dynamic> listDynamic = value;
      return MapEntry(key, listDynamic.cast<double>());
    });
    return faces;
  } catch (e) {
    return {};
  }
}

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> get _localFile async {
  final path = await _localPath;
  return File('$path/faces.json');
}
