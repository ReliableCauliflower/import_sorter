import 'dart:io';

class DartFile {
  final File file;
  final String packageName;

  const DartFile(this.file, this.packageName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DartFile &&
          runtimeType == other.runtimeType &&
          file == other.file &&
          packageName == other.packageName;

  @override
  int get hashCode => file.hashCode ^ packageName.hashCode;
}
