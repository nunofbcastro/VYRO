import 'dart:io';

Future<void> deleteTemporaryImage(String path) async {
  final file = File(path);
  if (!await file.exists()) return;
  // Pickers normally return a cache copy. Never delete a borrowed original.
  final root = await Directory.systemTemp.resolveSymbolicLinks();
  final resolved = await file.resolveSymbolicLinks();
  if (resolved.startsWith('$root${Platform.pathSeparator}'))
    await file.delete();
}
