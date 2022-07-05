import 'dart:io';

import 'package:args/args.dart';
import 'package:import_sorter/dart_file.dart';
import 'package:tint/tint.dart';
import 'package:yaml/yaml.dart';

import 'package:import_sorter/args.dart' as local_args;
import 'package:import_sorter/files.dart' as files;
import 'package:import_sorter/sort.dart' as sort;

void main(List<String> args) {
  // Parsing arguments
  final parser = ArgParser();
  parser.addFlag('emojis', abbr: 'e', negatable: false);
  parser.addFlag('ignore-config', negatable: false);
  parser.addFlag('help', abbr: 'h', negatable: false);
  parser.addFlag('exit-if-changed', negatable: false);
  parser.addFlag('no-comments', negatable: false);
  final argResults = parser.parse(args).arguments;
  if (argResults.contains('-h') || argResults.contains('--help')) {
    local_args.outputHelp();
  }

  final currentPath = Directory.current.path;
  /*
  Getting the package name and dependencies/dev_dependencies
  Package name is one factor used to identify project imports
  Dependencies/dev_dependencies names are used to identify package imports
  */
  final pubspecYamlFile = File('${currentPath}/pubspec.yaml');
  final pubspecYaml = loadYaml(pubspecYamlFile.readAsStringSync());

  final dependencies = [];

  final stopwatch = Stopwatch();
  stopwatch.start();

  final pubspecLockFile = File('${currentPath}/pubspec.lock');
  final pubspecLock = loadYaml(pubspecLockFile.readAsStringSync());
  dependencies.addAll(pubspecLock['packages'].keys);

  final ignoredFiles = [];
  final additionalPaths = <String>[];

  // Reading from config in pubspec.yaml safely
  if (!argResults.contains('--ignore-config')) {
    if (pubspecYaml.containsKey('import_sorter')) {
      final config = pubspecYaml['import_sorter'];
      if (config.containsKey('ignored_files')) {
        ignoredFiles.addAll(config['ignored_files']);
      }
      if (config.containsKey('additional_paths')) {
        final yamlList = config['additional_paths'];
        additionalPaths.addAll(List<String>.from(yamlList));
      }
    }
  }

  final exitOnChange = argResults.contains('--exit-if-changed');

  // Getting all the dart files for the project
  final dartFiles = files.dartFiles(
    currentPath: currentPath,
    args: args,
    additionalPaths: additionalPaths,
    basePackageName: pubspecYaml['name'],
  );
  final containsFlutter = dependencies.contains('flutter');
  if (containsFlutter) {
    final List<DartFile> filesToRemove = [];
    for (final dartFile in dartFiles) {
      if (dartFile.file.path.endsWith('generated_plugin_registrant.dart')) {
        filesToRemove.add(dartFile);
      }
    }
    dartFiles.removeWhere((file) => filesToRemove.contains(file));
  }

  for (final pattern in ignoredFiles) {
    dartFiles.removeWhere((file) =>
        RegExp(pattern).hasMatch(file.file.path.replaceFirst(currentPath, '')));
  }

  stdout.write('┏━━ Sorting ${dartFiles.length} dart files');

  // Sorting and writing to files
  final sortedFilesPaths = <String>[];
  final success = '✔'.green();

  for (final dartFile in dartFiles) {
    final file = dartFile.file;
    final filePath = file.path;

    final sortedFile = sort.sortImports(
      file.readAsLinesSync(),
      dartFile.packageName,
      exitOnChange,
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
