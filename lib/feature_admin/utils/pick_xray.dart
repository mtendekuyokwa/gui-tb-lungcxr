import 'package:file_picker/file_picker.dart';

/// Asks for one X-ray image; null when the picker is dismissed.
Future<PlatformFile?> pickXray() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg'],
  );
  return files.isEmpty ? null : files.first;
}
