import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// File name for an export, e.g. `lungcxr-reviews-2026-11-04.csv`.
String exportFileName(String kind, DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${day.year}-${two(day.month)}-${two(day.day)}';
  return 'lungcxr-${kind.replaceAll('_', '-')}-$date.csv';
}

/// Saves [csv] as a file: a browser download on web, a save dialog on
/// desktop and mobile. Returns false when the dialog was cancelled.
///
/// A UTF-8 byte-order mark leads the file so Excel reads accented patient
/// notes correctly instead of guessing a legacy encoding.
Future<bool> saveCsv(String csv, String fileName) async {
  final bytes = utf8.encode('﻿$csv');
  final saved = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: 'text/csv',
    type: FileType.custom,
    allowedExtensions: const ['csv'],
  );
  // The web download returns null but has started; elsewhere null = cancel.
  return saved != null || kIsWeb;
}
