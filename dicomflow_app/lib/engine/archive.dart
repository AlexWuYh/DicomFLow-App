import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../domain/errors.dart';

const maxExtractFiles = 100000;
const maxExtractBytes = 4 * 1024 * 1024 * 1024;
const maxRatio = 100.0;
const ratioFloorBytes = 32 * 1024 * 1024;
const maxInputBytes = 1024 * 1024 * 1024;

/// Android JNI / tests: extract [archive] into [dest] without a CLI binary.
Future<void> Function(File archive, Directory dest)? bundledArchiveExtract;

bool isUnsafeArchiveName(String name) {
  final rel = archiveMemberRelative(name);
  if (rel == null) return false;
  return rel == '..' || rel.startsWith('../') || rel.split('/').contains('..');
}

/// Archive member → relative path inside the dest. Strips Windows drives and a
/// leading `/` (common in hospital zips) but still rejects `..` after normalize.
String? archiveMemberRelative(String name) {
  var raw = name.trim().replaceAll('\\', '/');
  if (raw.isEmpty) return null;
  if (raw.startsWith('~')) return '..';
  if (raw.length >= 2 && raw[1] == ':') {
    raw = raw.substring(2);
  }
  while (raw.startsWith('/')) {
    raw = raw.substring(1);
  }
  final norm = p.posix.normalize(raw);
  if (norm.isEmpty || norm == '.') return null;
  return norm;
}

/// lsar prints ` /abs/path/archive.rar: RAR 5 ` as the first line — not a member.
bool isArchiveListingNoise(String line, File archive) {
  final t = line.trim();
  if (t.isEmpty) return true;
  final base = p.basename(archive.path);
  if (t == base || t == '$base:') return true;
  if (t.startsWith('$base:')) return true;
  final abs = p.normalize(archive.path);
  if (p.equals(p.normalize(t), abs)) return true;
  if (t.startsWith(abs)) return true;
  if (t.startsWith('$abs:')) return true;
  return false;
}

String canonicalPath(String path) {
  final abs = p.normalize(p.absolute(path));
  final missing = <String>[];
  var current = abs;
  while (true) {
    try {
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        var resolved = Directory(current).resolveSymbolicLinksSync();
        for (final part in missing.reversed) {
          resolved = p.join(resolved, part);
        }
        return resolved;
      }
      if (type == FileSystemEntityType.file && missing.isEmpty) {
        return File(current).resolveSymbolicLinksSync();
      }
    } catch (_) {}
    final parent = p.dirname(current);
    if (parent == current) return abs;
    missing.add(p.basename(current));
    current = parent;
  }
}

bool _escapesDest(String destDir, String targetPath) {
  final base = canonicalPath(destDir);
  final target = canonicalPath(targetPath);
  return target != base && !target.startsWith('$base${p.separator}');
}

String relativeInside(String root, String targetPath) {
  final base = canonicalPath(root);
  final target = canonicalPath(targetPath);
  if (target == base) return '';
  if (!target.startsWith('$base${p.separator}')) {
    throw EngineException(
      EngineException.invalidArchive,
      '归档包含非法路径（Zip Slip）',
      detail: targetPath,
    );
  }
  return p.relative(target, from: base);
}

String? detectArchiveKind(Uint8List magic) {
  if (magic.length >= 2 && magic[0] == 0x50 && magic[1] == 0x4b) return 'zip';
  if (magic.length >= 4 &&
      magic[0] == 0x52 &&
      magic[1] == 0x61 &&
      magic[2] == 0x72 &&
      magic[3] == 0x21) {
    return 'rar';
  }
  if (magic.length >= 4 &&
      magic[0] == 0x37 &&
      magic[1] == 0x7a &&
      magic[2] == 0xbc &&
      magic[3] == 0xaf) {
    return '7z';
  }
  return null;
}

/// Extract a zip into [destDir]. Directories and already-extracted trees are used as-is.
Future<Directory> prepareInput(
  FileSystemEntity input, {
  required Directory destDir,
  int maxFiles = maxExtractFiles,
  int maxBytes = maxExtractBytes,
  double maxCompressionRatio = maxRatio,
  int maxInput = maxInputBytes,
}) async {
  if (input is Directory) {
    if (!input.existsSync()) {
      throw const EngineException(EngineException.invalidArchive, '输入目录不存在');
    }
    return input;
  }

  final file = input as File;
  if (!file.existsSync()) {
    throw const EngineException(EngineException.invalidArchive, '找不到输入文件');
  }

  final compressedSize = file.lengthSync();
  if (compressedSize > maxInput) {
    throw EngineException(
      EngineException.archiveBomb,
      '输入压缩包超过大小限制',
      detail: 'bytes=$compressedSize max=$maxInput',
    );
  }

  final header = await file.openRead(0, 8).fold<BytesBuilder>(
    BytesBuilder(copy: false),
    (b, chunk) {
      b.add(chunk);
      return b;
    },
  );
  final magic = Uint8List.fromList(header.takeBytes());
  final kind = detectArchiveKind(magic);
  if (destDir.existsSync()) {
    destDir.deleteSync(recursive: true);
  }
  destDir.createSync(recursive: true);

  if (kind == 'rar' || kind == '7z') {
    try {
      await _extractWithTool(file, destDir, kind: kind!);
      _enforceExtractLimits(
        destDir,
        compressedSize: compressedSize,
        maxFiles: maxFiles,
        maxBytes: maxBytes,
        maxCompressionRatio: maxCompressionRatio,
      );
      return destDir;
    } catch (e) {
      _cleanup(destDir);
      if (e is EngineException) rethrow;
      throw EngineException(
        EngineException.invalidArchive,
        '无法解压 $kind',
        detail: e.toString(),
      );
    }
  }
  if (kind != 'zip' && p.extension(file.path).toLowerCase() != '.zip') {
    throw const EngineException(EngineException.invalidArchive, '无法识别的压缩包（需要 zip / rar / 7z）');
  }

  late Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  } catch (e) {
    _cleanup(destDir);
    throw EngineException(
      EngineException.invalidArchive,
      '无法解压 zip',
      detail: e.toString(),
    );
  }

  var written = 0;
  var fileCount = 0;
  try {
    for (final entry in archive) {
      if (entry.isSymbolicLink) {
        throw EngineException(
          EngineException.invalidArchive,
          '归档包含非法路径（符号链接）',
          detail: entry.name,
        );
      }
      final rel = archiveMemberRelative(entry.name);
      if (rel == null) continue;
      if (isUnsafeArchiveName(entry.name)) {
        throw EngineException(
          EngineException.invalidArchive,
          '归档包含非法路径（Zip Slip）',
          detail: entry.name,
        );
      }
      final target = p.join(destDir.path, rel);
      if (_escapesDest(destDir.path, target)) {
        throw EngineException(
          EngineException.invalidArchive,
          '归档包含非法路径（Zip Slip）',
          detail: entry.name,
        );
      }

      if (!entry.isFile) {
        Directory(target).createSync(recursive: true);
        continue;
      }

      fileCount += 1;
      final bytes = entry.content;
      written += bytes.length;
      if (fileCount > maxFiles) {
        throw EngineException(
          EngineException.archiveBomb,
          '归档内文件数超过限制',
          detail: 'count=$fileCount',
        );
      }
      if (written > maxBytes) {
        throw EngineException(
          EngineException.archiveBomb,
          '解压后体积超过限制',
          detail: 'bytes=$written',
        );
      }
      final denom = max(1, compressedSize);
      final ratio = written / denom;
      if (ratio > maxCompressionRatio && written > ratioFloorBytes) {
        throw EngineException(
          EngineException.archiveBomb,
          '疑似 zip bomb（压缩比过高）',
          detail: 'ratio=${ratio.toStringAsFixed(1)}',
        );
      }

      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes, flush: true);
    }
  } catch (e) {
    _cleanup(destDir);
    if (e is EngineException) rethrow;
    throw EngineException(
      EngineException.invalidArchive,
      '解压失败',
      detail: e.toString(),
    );
  }

  return destDir;
}

Future<void> _extractWithTool(File archive, Directory dest, {required String kind}) async {
  final hook = bundledArchiveExtract;
  if (hook != null) {
    final staging = Directory.systemTemp.createTempSync('dicomflow_stg_');
    try {
      await hook(archive, staging);
      assertExtractTreeSafe(staging);
      _relocateStaging(staging, dest);
    } finally {
      _cleanup(staging);
    }
    return;
  }

  final tool = resolveExtractor(kind);
  if (tool == null) {
    throw EngineException(
      EngineException.invalidArchive,
      '无法解压 $kind：安装包内解压组件不可用。请把压缩包转为 zip 后再试。',
    );
  }

  final listed = await listArchiveMembers(tool, archive);
  for (final name in listed) {
    if (isArchiveListingNoise(name, archive)) continue;
    if (isUnsafeArchiveName(name)) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（Zip Slip）',
        detail: name,
      );
    }
  }

  final staging = Directory.systemTemp.createTempSync('dicomflow_stg_');
  try {
    await _runExtractor(tool, archive, staging);
    assertExtractTreeSafe(staging);
    _relocateStaging(staging, dest);
  } finally {
    _cleanup(staging);
  }
}

Future<void> _runExtractor(String tool, File archive, Directory dest) async {
  late List<String> args;
  final base = p.basename(tool).toLowerCase();
  if (base.startsWith('unar')) {
    args = ['-f', '-D', '-q', '-o', dest.path, archive.path];
  } else if (base.contains('7z') || base == '7zz' || base == '7zz.exe' || base == '7z.exe') {
    args = ['x', '-y', '-o${dest.path}', archive.path];
  } else {
    args = ['x', '-o+', dest.path, archive.path];
  }
  final result = await Process.run(tool, args).timeout(
    const Duration(minutes: 10),
    onTimeout: () {
      throw const EngineException(EngineException.invalidArchive, '解压超时');
    },
  );
  if (result.exitCode != 0) {
    throw EngineException(
      EngineException.invalidArchive,
      '解压失败',
      detail: '${result.stderr}\n${result.stdout}',
    );
  }
}

/// Walk [root] and fail if any symlink or path escapes the directory.
void assertExtractTreeSafe(Directory root) {
  if (!root.existsSync()) return;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is Link) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（符号链接）',
        detail: entity.path,
      );
    }
    if (_escapesDest(root.path, entity.path)) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（Zip Slip）',
        detail: entity.path,
      );
    }
    final rel = relativeInside(root.path, entity.path);
    if (rel.isNotEmpty && isUnsafeArchiveName(rel)) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（Zip Slip）',
        detail: entity.path,
      );
    }
  }
}

void _relocateStaging(Directory staging, Directory dest) {
  for (final entity in staging.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = relativeInside(staging.path, entity.path);
    if (rel.isEmpty || isUnsafeArchiveName(rel)) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（Zip Slip）',
        detail: rel,
      );
    }
    final target = File(p.join(dest.path, rel));
    if (_escapesDest(dest.path, target.path)) {
      throw EngineException(
        EngineException.invalidArchive,
        '归档包含非法路径（Zip Slip）',
        detail: rel,
      );
    }
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}

Future<List<String>> listArchiveMembers(String tool, File archive) async {
  final base = p.basename(tool).toLowerCase();
  try {
    if (base.contains('7z') || base == '7zz' || base == '7zz.exe' || base == '7z.exe') {
      final result = await Process.run(tool, ['l', '-slt', archive.path]);
      if (result.exitCode != 0) return const [];
      return _parse7zSlt(result.stdout.toString(), archiveName: p.basename(archive.path));
    }
    if (base.startsWith('unar') || base == 'lsar' || base == 'lsar.exe') {
      final lsar = _siblingTool(tool, 'lsar') ?? resolveExtractorBinary('lsar');
      if (lsar == null) return const [];
      final result = await Process.run(lsar, [archive.path]);
      if (result.exitCode != 0) return const [];
      return [
        for (final line in result.stdout.toString().split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];
    }
    if (base.startsWith('unrar')) {
      final result = await Process.run(tool, ['lb', archive.path]);
      if (result.exitCode != 0) return const [];
      return [
        for (final line in result.stdout.toString().split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];
    }
  } catch (_) {}
  return const [];
}

List<String> _parse7zSlt(String stdout, {required String archiveName}) {
  final names = <String>[];
  for (final line in stdout.split('\n')) {
    if (line.startsWith('Path = ') && !line.endsWith(archiveName)) {
      names.add(line.substring(7).trim());
    }
  }
  return names;
}

String? _siblingTool(String toolPath, String name) {
  final dir = p.dirname(toolPath);
  if (dir.isEmpty || dir == '.') return null;
  final candidate = File(p.join(dir, name));
  if (candidate.existsSync()) return candidate.path;
  final win = File(p.join(dir, '$name.exe'));
  if (win.existsSync()) return win.path;
  return null;
}

/// Bundled 7-Zip next to the executable or in macOS Resources (like ffmpeg).
List<String> bundledExtractorCandidates() {
  final out = <String>[];
  final env = Platform.environment['DICOMFLOW_7Z'];
  if (env != null && env.isNotEmpty) out.add(env);
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    out.addAll([
      p.join(exeDir, '7zz'),
      p.join(exeDir, '7z.exe'),
      p.join(exeDir, '7z'),
      p.normalize(p.join(exeDir, '..', 'Resources', '7zz')),
      p.normalize(p.join(exeDir, '..', 'Resources', '7z')),
    ]);
  } catch (_) {}
  return out;
}

/// Resolve bundled 7-Zip, then unar/7z/unrar, without requiring Unix `which`.
String? resolveExtractor(String kind) {
  for (final path in bundledExtractorCandidates()) {
    if (File(path).existsSync()) return path;
  }
  final names = kind == 'rar'
      ? <String>[
          'unar',
          '/opt/homebrew/bin/unar',
          '/usr/local/bin/unar',
          'unrar',
          '7z',
          '7zz',
          '7z.exe',
          r'C:\Program Files\7-Zip\7z.exe',
          r'C:\Program Files (x86)\7-Zip\7z.exe',
        ]
      : <String>[
          'unar',
          '/opt/homebrew/bin/unar',
          '/usr/local/bin/unar',
          '7z',
          '7zz',
          '7z.exe',
          r'C:\Program Files\7-Zip\7z.exe',
          r'C:\Program Files (x86)\7-Zip\7z.exe',
        ];
  for (final name in names) {
    final found = resolveExtractorBinary(name);
    if (found != null) return found;
  }
  return null;
}

String? resolveExtractorBinary(String name) {
  if (name.contains('/') || name.contains('\\')) {
    if (File(name).existsSync()) return name;
    return null;
  }
  if (_canExecute(name)) return name;
  try {
    final which = Process.runSync('which', [name]);
    if (which.exitCode == 0) {
      final path = which.stdout.toString().trim();
      if (path.isNotEmpty) return path;
    }
  } catch (_) {}
  try {
    final where = Process.runSync('where', [name]);
    if (where.exitCode == 0) {
      final path = where.stdout.toString().trim().split(RegExp(r'\r?\n')).first;
      if (path.isNotEmpty) return path;
    }
  } catch (_) {}
  return null;
}

bool _canExecute(String name) {
  try {
    final result = Process.runSync(name, ['-h']);
    return result.exitCode == 0 || result.exitCode == 1 || result.exitCode == 2;
  } catch (_) {
    try {
      final result = Process.runSync(name, []);
      return result.exitCode == 0 || result.exitCode == 1 || result.exitCode == 2;
    } catch (_) {
      return false;
    }
  }
}

void _enforceExtractLimits(
  Directory dest, {
  required int compressedSize,
  required int maxFiles,
  required int maxBytes,
  required double maxCompressionRatio,
}) {
  var files = 0;
  var bytes = 0;
  for (final entity in dest.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    files += 1;
    bytes += entity.lengthSync();
  }
  if (files > maxFiles) {
    throw EngineException(
      EngineException.archiveBomb,
      '归档内文件数超过限制',
      detail: 'count=$files',
    );
  }
  if (bytes > maxBytes) {
    throw EngineException(
      EngineException.archiveBomb,
      '解压后体积超过限制',
      detail: 'bytes=$bytes',
    );
  }
  final ratio = bytes / (compressedSize == 0 ? 1 : compressedSize);
  if (ratio > maxCompressionRatio && bytes > ratioFloorBytes) {
    throw EngineException(
      EngineException.archiveBomb,
      '疑似 zip bomb（压缩比过高）',
      detail: 'ratio=${ratio.toStringAsFixed(1)}',
    );
  }
}

void _cleanup(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}
