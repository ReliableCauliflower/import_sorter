import 'dart:io';

import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'dart_file.dart';

/// Get all the dart files for the project and the contents
List<DartFile> dartFiles({
  required String currentPath,
  required List<String> args,
  required List<String> additionalPaths,
  required List<String> ignorePaths,
  required String basePackageName,
}) {
  final dartFiles = <DartFile>[];
  final additionalPathsFileEntities = <FileSystemEntity>[];
  for (final path in additionalPaths) {
    additionalPathsFileEntities.addAll(_readDir(currentPath, path));
  }
  final allContents = [
    ..._readDir(currentPath, 'lib'),
    ..._readDir(currentPath, 'bin'),
    ..._readDir(currentPath, 'test'),
    ..._readDir(currentPath, 'tests'),
    ..._readDir(currentPath, 'test_driver'),
    ..._readDir(currentPath, 'integration_test'),
    ...additionalPathsFileEntities,
  ];

  String lastPackageDirPath = currentPath;
  String packageName = basePackageName;

  dirContentsLoop:
  for (final fileSysEntity in allContents) {
    if (fileSysEntity is File) {
      final filePath = fileSysEntity.path;
      String relativePath = filePath.replaceFirst(currentPath, '');
      if (relativePath.startsWith(separator)) {
        relativePath = relativePath.replaceRange(0, 1, '');
      }
      for (String ignorePath in ignorePaths) {
        if (ignorePath.startsWith(separator)) {
          ignorePath = ignorePath.replaceRange(0, 1, '');
        }
        if (relativePath.startsWith(ignorePath)) {
          continue dirContentsLoop;
        }
      }
      if (filePath.endsWith('.dart')) {
        if (!filePath.startsWith(lastPackageDirPath)) {
          packageName = basePackageName;
        }
        dartFiles.add(DartFile(fileSysEntity, packageName));
      } else if (filePath.endsWith('pubspec.yaml')) {
        try {
          final pubspecYaml = loadYaml(fileSysEntity.readAsStringSync());
          final pubspecPackageName = pubspecYaml['name'];
          if (pubspecPackageName != null) {
            packageName = pubspecPackageName;
            lastPackageDirPath = fileSysEntity.parent.path;
          }
        } catch (e) {
          stdout.write('An error occured parsing the $filePath:\n$e');
          continue;
        }
      }
    }
  }

  // If there are only certain files given via args filter the others out
  var onlyCertainFiles = false;
  for (final arg in args) {
    if (!onlyCertainFiles) {
      onlyCertainFiles = arg.endsWith("dart");
    }
  }

  if (onlyCertainFiles) {
    final patterns = args.where((arg) => !arg.startsWith("-"));
    final filesToKeep = <DartFile>[];

    for (final file in dartFiles) {
      var keep = false;
      for (final pattern in patterns) {
        if (RegExp(pattern).hasMatch(file.file.path)) {
          keep = true;
          break;
        }
      }
      if (keep) {
        filesToKeep.add(file);
      }
    }
    return filesToKeep;
  }

  return dartFiles;
}

List<FileSystemEntity> _readDir(String currentPath, String name) {
  final dir = Directory('$currentPath/$name');
  if (dir.existsSync()) {
    return dir.listSync(recursive: true);
  }
  return [];
}
