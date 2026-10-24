import 'dart:io';

Future<void> deleteTemporaryImage(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
