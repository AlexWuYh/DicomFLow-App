import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> appDataDir() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return Directory(p.join(home, '.dicomflow'));
  }
}

Future<File> defaultJobsFile() async {
  final root = await appDataDir();
  return File(p.join(root.path, 'DicomFlow', 'jobs.json'));
}

Future<File> defaultSettingsFile() async {
  final root = await appDataDir();
  return File(p.join(root.path, 'DicomFlow', 'settings.json'));
}

Future<Directory> jobOutputDir(String jobId) async {
  final root = await appDataDir();
  return Directory(p.join(root.path, 'DicomFlow', 'outputs', jobId));
}
