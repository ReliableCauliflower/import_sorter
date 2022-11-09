import 'dart:io';

class DartFileInfo {
  final File file;
  final String packageName;

  const DartFileInfo({
    required this.file,
    required this.packageName,
  });
}
