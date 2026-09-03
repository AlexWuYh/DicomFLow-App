import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

String mediaMimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.zip')) return 'application/zip';
  return 'video/mp4';
}

Future<void> shareMediaFile(File file) async {
  if (!file.existsSync()) {
    throw const FileSystemException('文件已删除');
  }
  final name = file.uri.pathSegments.isEmpty
      ? file.path
      : file.uri.pathSegments.last;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mediaMimeType(name), name: name)],
      title: '分享给医生',
    ),
  );
}

/// Android: system save sheet. Desktop: reveal in folder.
Future<void> saveOrRevealFile(File file) async {
  if (!file.existsSync()) {
    throw const FileSystemException('文件已删除');
  }
  if (Platform.isAndroid) {
    await FilePicker.saveFile(
      fileName: p.basename(file.path),
      bytes: file.readAsBytesSync(),
      mimeType: mediaMimeType(p.basename(file.path)),
    );
    return;
  }
  await revealInFolder(file);
}

bool _escapesDirectory(String destDir, String targetPath) {
  final base = p.normalize(p.absolute(destDir));
  final target = p.normalize(p.absolute(targetPath));
  return target != base && !target.startsWith('$base${p.separator}');
}

File uniqueExportTarget(Directory dest, String basename) {
  var target = File(p.join(dest.path, basename));
  if (!target.existsSync()) return target;
  final stem = p.basenameWithoutExtension(basename);
  final ext = p.extension(basename);
  for (var i = 1; i < 1000; i++) {
    target = File(p.join(dest.path, '${stem}_$i$ext'));
    if (!target.existsSync()) return target;
  }
  throw const FileSystemException('无法生成不冲突的导出文件名');
}

/// Copy existing [files] into [dest], skipping missing sources. Returns count written.
int copyOutputsToDirectory(List<File> files, Directory dest) {
  dest.createSync(recursive: true);
  var written = 0;
  for (final file in files) {
    if (!file.existsSync()) continue;
    final target = uniqueExportTarget(dest, p.basename(file.path));
    if (_escapesDirectory(dest.path, target.path)) {
      throw const FileSystemException('导出路径不安全');
    }
    if (p.equals(p.normalize(file.absolute.path), p.normalize(target.absolute.path))) {
      written += 1;
      continue;
    }
    file.copySync(target.path);
    written += 1;
  }
  return written;
}

String exportPackageFileName({String? sourceFilename, DateTime? now}) {
  var stem = p.basenameWithoutExtension((sourceFilename ?? '').trim());
  stem = stem.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
  stem = stem.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (stem.isEmpty) stem = 'dicomflow';
  final t = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return '${stem}_$stamp.zip';
}

bool _isZipFile(File file) => p.extension(file.path).toLowerCase() == '.zip';

/// Bytes of the single package to export: existing result.zip, or a new zip of media.
Uint8List buildExportZipBytes(List<File> files) {
  final existingZip = [
    for (final f in files)
      if (f.existsSync() && _isZipFile(f)) f,
  ];
  if (existingZip.isNotEmpty) {
    return Uint8List.fromList(existingZip.first.readAsBytesSync());
  }
  final archive = Archive();
  for (final f in files) {
    if (!f.existsSync() || _isZipFile(f)) continue;
    archive.add(ArchiveFile.bytes(p.basename(f.path), f.readAsBytesSync()));
  }
  if (archive.isEmpty) {
    throw const FileSystemException('没有可打包的文件');
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Write one timestamped zip into [dest]. Returns the created file.
File exportPackageToDirectory(
  List<File> files,
  Directory dest, {
  String? sourceFilename,
  DateTime? now,
}) {
  dest.createSync(recursive: true);
  final name = exportPackageFileName(sourceFilename: sourceFilename, now: now);
  final target = uniqueExportTarget(dest, name);
  if (_escapesDirectory(dest.path, target.path)) {
    throw const FileSystemException('导出路径不安全');
  }
  target.writeAsBytesSync(buildExportZipBytes(files), flush: true);
  return target;
}

/// Ask for a folder and write one packaged zip. Empty string = cancelled.
Future<String> exportOutputFiles(List<File> files, {String? sourceFilename}) async {
  final existing = [for (final f in files) if (f.existsSync()) f];
  if (existing.isEmpty) {
    throw const FileSystemException('没有可导出的文件');
  }
  final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出目录');
  if (dir == null || dir.isEmpty) return '';
  final out = exportPackageToDirectory(
    existing,
    Directory(dir),
    sourceFilename: sourceFilename,
  );
  return p.basename(out.path);
}

Future<void> exportOutputFilesWithFeedback(
  BuildContext context,
  List<File> files, {
  String? sourceFilename,
}) async {
  try {
    final name = await exportOutputFiles(files, sourceFilename: sourceFilename);
    if (!context.mounted || name.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出 $name')),
    );
  } catch (e) {
    if (!context.mounted) return;
    final message = e is FileSystemException && e.message.isNotEmpty
        ? e.message
        : '无法完成该操作';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> revealInFolder(File file) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', file.path]);
    return;
  }
  if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', file.path]);
    return;
  }
  if (Platform.isLinux) {
    await Process.run('xdg-open', [file.parent.path]);
  }
}

Future<void> runFileAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (!context.mounted) return;
    final message = e is FileSystemException && (e.message.isNotEmpty)
        ? e.message
        : '无法完成该操作';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
