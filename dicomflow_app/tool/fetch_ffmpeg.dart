/// Downloads official static ffmpeg/ffprobe into the Flutter runner trees.
///
/// Sources (latest release):
/// - macOS: Martin Riedl static builds (ffmpeg 9.x)
/// - Windows: Gyan / Codex FFmpeg essentials (includes libx264)
///
/// Run from repo: `dart run dicomflow_app/tool/fetch_ffmpeg.dart`
/// or from the Flutter package: `dart run tool/fetch_ffmpeg.dart`
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const macosFfmpegArm =
    'https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip';
const macosFfprobeArm =
    'https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip';
const macosFfmpegX64 =
    'https://ffmpeg.martin-riedl.de/redirect/latest/macos/amd64/release/ffmpeg.zip';
const macosFfprobeX64 =
    'https://ffmpeg.martin-riedl.de/redirect/latest/macos/amd64/release/ffprobe.zip';
const windowsEssentials =
    'https://github.com/GyanD/codexffmpeg/releases/download/9.0.1/ffmpeg-9.0.1-essentials_build.zip';

Directory packageRoot() {
  final script = File(Platform.script.toFilePath());
  // .../dicomflow_app/tool/fetch_ffmpeg.dart
  return script.parent.parent;
}

Future<void> main() async {
  final root = packageRoot();
  stdout.writeln('DicomFlow ffmpeg fetch → ${root.path}');
  final cache = Directory(p.join(root.path, 'third_party', 'ffmpeg'))
    ..createSync(recursive: true);

  if (Platform.isMacOS || Platform.environment['FETCH_MACOS'] == '1') {
    await _fetchMacos(root, cache);
  }
  await _fetchWindows(root, cache);
  stdout.writeln('Done. Binaries are gitignored; rebuild the app to bundle them.');
}

Future<void> _fetchMacos(Directory root, Directory cache) async {
  final armDir = Directory(p.join(cache.path, 'darwin-arm64'))..createSync(recursive: true);
  final x64Dir = Directory(p.join(cache.path, 'darwin-x64'))..createSync(recursive: true);
  await _downloadZipExtractBin(macosFfmpegArm, armDir, 'ffmpeg');
  await _downloadZipExtractBin(macosFfprobeArm, armDir, 'ffprobe');
  try {
    await _downloadZipExtractBin(macosFfmpegX64, x64Dir, 'ffmpeg');
    await _downloadZipExtractBin(macosFfprobeX64, x64Dir, 'ffprobe');
  } catch (e) {
    stdout.writeln('macOS x64 download skipped: $e');
  }

  final dest = Directory(p.join(root.path, 'macos', 'Runner', 'Resources'))
    ..createSync(recursive: true);
  for (final name in ['ffmpeg']) {
    final arm = File(p.join(armDir.path, name));
    final x64 = File(p.join(x64Dir.path, name));
    final out = File(p.join(dest.path, name));
    if (arm.existsSync() && x64.existsSync()) {
      final r = Process.runSync('lipo', ['-create', arm.path, x64.path, '-output', out.path]);
      if (r.exitCode != 0) {
        arm.copySync(out.path);
      }
    } else if (arm.existsSync()) {
      arm.copySync(out.path);
    } else if (x64.existsSync()) {
      x64.copySync(out.path);
    }
    if (out.existsSync()) {
      Process.runSync('chmod', ['+x', out.path]);
      Process.runSync('codesign', ['--force', '--sign', '-', out.path]);
      stdout.writeln('macOS bundled $name (${out.lengthSync()} bytes)');
    }
  }
}

Future<void> _fetchWindows(Directory root, Directory cache) async {
  final winDir = Directory(p.join(cache.path, 'windows-x64'))..createSync(recursive: true);
  try {
    await _downloadZipExtractBin(windowsEssentials, winDir, 'ffmpeg.exe');
    await _downloadZipExtractBin(windowsEssentials, winDir, 'ffprobe.exe', reuseZip: true);
  } catch (e) {
    stdout.writeln('Windows ffmpeg download failed (ok on Mac if later copied): $e');
    return;
  }
  final dest = Directory(p.join(root.path, 'windows', 'runner', 'resources', 'ffmpeg'))
    ..createSync(recursive: true);
  for (final name in ['ffmpeg.exe', 'ffprobe.exe']) {
    final src = File(p.join(winDir.path, name));
    if (src.existsSync()) {
      src.copySync(p.join(dest.path, name));
      stdout.writeln('Windows bundled $name (${src.lengthSync()} bytes)');
    }
  }
}

final _zipCache = <String, File>{};

Future<void> _downloadZipExtractBin(
  String url,
  Directory dest,
  String binaryName, {
  bool reuseZip = false,
}) async {
  dest.createSync(recursive: true);
  final existing = File(p.join(dest.path, binaryName));
  if (existing.existsSync() && existing.lengthSync() > 1000000) {
    stdout.writeln('cached $binaryName');
    return;
  }

  File zipFile;
  if (reuseZip && _zipCache.containsKey(url)) {
    zipFile = _zipCache[url]!;
  } else {
    stdout.writeln('GET $url');
    zipFile = File(p.join(dest.path, '${binaryName.split('.').first}.download.zip'));
    await _download(url, zipFile);
    _zipCache[url] = zipFile;
  }

  final bytes = zipFile.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? match;
  for (final f in archive) {
    if (!f.isFile) continue;
    final base = p.basename(f.name);
    if (base == binaryName || base == p.basenameWithoutExtension(binaryName)) {
      match = f;
      break;
    }
  }
  match ??= () {
    for (final f in archive) {
      if (!f.isFile) continue;
      if (p.basename(f.name).toLowerCase() == binaryName.toLowerCase()) return f;
    }
    return null;
  }();
  if (match == null) {
    throw StateError('zip from $url has no $binaryName');
  }
  final out = File(p.join(dest.path, binaryName));
  out.writeAsBytesSync(match.content as List<int>);
  if (!binaryName.endsWith('.exe')) {
    Process.runSync('chmod', ['+x', out.path]);
  }
}

Future<void> _download(String url, File dest) async {
  dest.parent.createSync(recursive: true);
  final client = HttpClient();
  try {
    var request = await client.getUrl(Uri.parse(url));
    request.followRedirects = true;
    var response = await request.close();
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final loc = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (loc != null) {
        request = await client.getUrl(Uri.parse(loc));
        response = await request.close();
      }
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    final sink = dest.openWrite();
    await response.pipe(sink);
  } finally {
    client.close(force: true);
  }
}
