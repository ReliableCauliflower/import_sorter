import 'dart:io';

import 'package:pre_commit_helpers/pre_commit_helpers.dart';
import 'package:yaml/yaml.dart';

import 'package:import_sorter/models/dart_file_info.dart';
import 'package:import_sorter/sort.dart' as sort;

const importSorterName = 'import_sorter';
const ignorePathsName = 'ignore_paths';
const additionalPathsName = 'additional_paths';
const ignorePatternsName = 'ignore_patterns';

void main(List<String> args) {
  final currentPath = Directory.current.path;

  final pubspecPath = '${currentPath}/pubspec.yaml';

  final stopwatch = Stopwatch();
  stopwatch.start();

  final dependencies = [];

  final pubspecLockFile = File('${currentPath}/pubspec.lock');
  final pubspecLock = loadYaml(pubspecLockFile.readAsStringSync());
  dependencies.addAll(pubspecLock['packages'].keys);

  final ignorePaths = getArgList(
    pubspecPath: pubspecPath,
    configName: importSorterName,
    argName: ignorePathsName,
  );
  final additionalPaths = getArgList(
    pubspecPath: pubspecPath,
    configName: importSorterName,
    argName: additionalPathsName,
  );

  final ignorePatterns = getArgList(
    pubspecPath: pubspecPath,
    configName: importSorterName,
    argName: ignorePatternsName,
  );

  // Getting all the dart files for the project
  final packagesData = getPackagesData(
    currentPath: currentPath,
    additionalPaths: additionalPaths,
    ignorePaths: ignorePaths,
    ignorePatterns: ignorePatterns,
  );
  final List<DartFileInfo> dartFilesInfo = [];
  for (final packageData in packagesData) {
    for (final dartFile in packageData.dartFiles) {
      dartFilesInfo.add(DartFileInfo(
        file: dartFile,
        packageName: packageData.packageName,
      ));
    }
  }
  final containsFlutter = dependencies.contains('flutter');
  if (containsFlutter) {
    final List<DartFileInfo> filesToRemove = [];
    for (final dartFileInfo in dartFilesInfo) {
      if (dartFileInfo.file.path.endsWith('generated_plugin_registrant.dart')) {
        filesToRemove.add(dartFileInfo);
      }
    }
    dartFilesInfo.removeWhere((file) => filesToRemove.contains(file));
  }

  stdout.write('┏━━ Sorting ${dartFilesInfo.length} dart files');

  // Sorting and writing to files
  final sortedFilesPaths = <String>[];
  final success = '✔';

  for (final dartFile in dartFilesInfo) {
    final file = dartFile.file;
    final filePath = file.path;

    final sortedFile = sort.sortImports(
      file.readAsLinesSync(),
      dartFile.packageName,
      filePath,
    );
    if (!sortedFile.updated) {
      continue;
    }
    file.writeAsStringSync(sortedFile.sortedFile);
    sortedFilesPaths.add(filePath);
  }

  stopwatch.stop();

  // Outputting results
  if (sortedFilesPaths.length > 1) {
    stdout.write("\n");
  }
  for (int i = 0; i < sortedFilesPaths.length; i++) {
    final filePath = sortedFilesPaths[i];
    stdout.write(
        '${sortedFilesPaths.length == 1 ? '\n' : ''}┃  ${i == sortedFilesPaths.length - 1 ? '┗' : '┣'}━━ ${success} Sorted imports for ${filePath.replaceFirst(currentPath, '')}/');
    String filename = filePath.split(Platform.pathSeparator).last;
    stdout.write(filename + "\n");
  }

  if (sortedFilesPaths.length == 0) {
    stdout.write("\n");
  }
  stdout.write(
      '┗━━ ${success} Sorted ${sortedFilesPaths.length} files in ${stopwatch.elapsed.inSeconds}.${stopwatch.elapsedMilliseconds} seconds\n');
}
