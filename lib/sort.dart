import 'dart:io';

import 'package:path/path.dart';

/// Sort the imports
/// Returns the sorted file as a string at
/// index 0 and the number of sorted imports
/// at index 1
ImportSortData sortImports(
  List<String> lines,
  String packageName,
  bool exitIfChanged,
  String filePath,
) {
  final beforeImportLines = <String>[];
  final afterImportLines = <String>[];

  final dartImports = <String>[];
  final flutterImports = <String>[];
  final packageImports = <String>[];
  final projectRelativeImports = <String>[];
  final projectImports = <String>[];

  bool noImports() =>
      dartImports.isEmpty &&
      flutterImports.isEmpty &&
      packageImports.isEmpty &&
      projectImports.isEmpty &&
      projectRelativeImports.isEmpty;

  var isMultiLineString = false;

  for (var i = 0; i < lines.length; i++) {
    // Check if line is in multiline string
    if (_timesContained(lines[i], "'''") == 1 ||
        _timesContained(lines[i], '"""') == 1) {
      isMultiLineString = !isMultiLineString;
    }

    final line = lines[i];
    const packageImportStart = 'package:';
    const flutterPackageImportStart = 'package:flutter/';
    final relativePackageImportStart = 'package:$packageName/';

    // If line is an import line
    if (line.startsWith('import ') &&
        line.endsWith(';') &&
        !isMultiLineString) {
      if (line.contains('dart:')) {
        dartImports.add(lines[i]);
      } else if (line.contains(flutterPackageImportStart)) {
        flutterImports.add(line);
      } else if (line.contains(relativePackageImportStart)) {
        final packagePathIndex = line.indexOf(relativePackageImportStart) +
            relativePackageImportStart.length;
        final packageRelativePath =
            line.substring(packagePathIndex, line.lastIndexOf("'"));
        if (packageRelativePath.startsWith(packageName)) {
          projectImports.add(line);
        } else {
          final packageEntryIndex = filePath.lastIndexOf('lib/');
          if (packageEntryIndex < 0) {
            projectImports.add(line);
          } else {
            final relativePathStartIndex = packageEntryIndex + 4;
            final fileRelativePath = filePath.substring(relativePathStartIndex);
            projectRelativeImports.add(
              _packageRelativeImportFromPaths(
                packageRelativePath,
                fileRelativePath,
              ),
            );
          }
        }
      } else if (line.contains(packageImportStart)) {
        packageImports.add(line);
      } else {
        projectRelativeImports.add(line);
      }
    } else if (noImports()) {
      beforeImportLines.add(line);
    } else {
      afterImportLines.add(line);
    }
  }

  // If no imports return original string of lines
  if (noImports()) {
    var joinedLines = lines.join('\n');
    if (joinedLines.endsWith('\n') && !joinedLines.endsWith('\n\n')) {
      joinedLines += '\n';
    } else if (!joinedLines.endsWith('\n')) {
      joinedLines += '\n';
    }
    return ImportSortData(joinedLines, false);
  }

  // Remove spaces
  if (beforeImportLines.isNotEmpty) {
    if (beforeImportLines.last.trim() == '') {
      beforeImportLines.removeLast();
    }
  }

  final sortedLines = <String>[...beforeImportLines];

  // Adding content conditionally
  if (beforeImportLines.isNotEmpty) {
    sortedLines.add('');
  }
  if (dartImports.isNotEmpty) {
    dartImports.sort();
    sortedLines.addAll(dartImports);
  }
  if (flutterImports.isNotEmpty) {
    if (dartImports.isNotEmpty) sortedLines.add('');
    flutterImports.sort();
    sortedLines.addAll(flutterImports);
  }
  if (packageImports.isNotEmpty) {
    if (dartImports.isNotEmpty || flutterImports.isNotEmpty) {
      sortedLines.add('');
    }
    packageImports.sort();
    sortedLines.addAll(packageImports);
  }
  if (projectImports.isNotEmpty || projectRelativeImports.isNotEmpty) {
    if (dartImports.isNotEmpty ||
        flutterImports.isNotEmpty ||
        packageImports.isNotEmpty) {
      sortedLines.add('');
    }
    projectImports.sort();
    projectRelativeImports.sort();
    sortedLines.addAll(projectImports);
    sortedLines.addAll(projectRelativeImports);
  }

  sortedLines.add('');

  var addedCode = false;
  for (var j = 0; j < afterImportLines.length; j++) {
    if (afterImportLines[j] != '') {
      sortedLines.add(afterImportLines[j]);
      addedCode = true;
    }
    if (addedCode && afterImportLines[j] == '') {
      sortedLines.add(afterImportLines[j]);
    }
  }
  sortedLines.add('');

  final sortedFile = sortedLines.join('\n');
  final original = lines.join('\n') + '\n';
  if (exitIfChanged && original != sortedFile) {
    exit(1);
  }
  if (original == sortedFile) {
    return ImportSortData(original, false);
  }

  return ImportSortData(sortedFile, true);
}

String _packageRelativeImportFromPaths(
  String packageRelativePath,
  String fileRelativePath,
) {
  final packageRelativePathList = split(packageRelativePath);
  final fileRelativePathList = split(fileRelativePath);
  for (int i = 0; i < fileRelativePathList.length; ++i) {
    final filePathPart = fileRelativePathList[i];
    final packagePathPart = packageRelativePathList[i];

    if (filePathPart == packagePathPart) {
      continue;
    } else {
      final packageRelativePath = joinAll([
        '../' * (fileRelativePathList.length - i - 1),
        ...packageRelativePathList.sublist(i),
      ]);
      return "import '$packageRelativePath';";
    }
  }
  throw Exception(
    'Failed to update package path ($packageRelativePath) '
    'for the file ($fileRelativePath)',
  );
}

/// Get the number of times a string contains another
/// string
int _timesContained(String string, String looking) =>
    string.split(looking).length - 1;

/// Data to return from a sort
class ImportSortData {
  final String sortedFile;
  final bool updated;

  const ImportSortData(this.sortedFile, this.updated);
}
