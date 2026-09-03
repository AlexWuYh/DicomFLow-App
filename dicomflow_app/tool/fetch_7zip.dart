/// Downloads official 7-Zip into the Flutter runner trees (rar / 7z extract).
///
/// - macOS: 7zz universal binary from 7-zip.org
/// - Windows: 7z.exe + 7z.dll from the x64 installer
///
/// Android uses 7-Zip-JBinding (JNI), not these CLI files.
///
/// Run from the Flutter package: `dart run tool/fetch_7zip.dart`
library;

import 'dart:io';

import 'package:path/path.dart' as p;

const sevenZipVersion = '2501';
const macUrl = 'https://www.7-zip.org/a/7z$sevenZipVersion-mac.tar.xz';
const winExeUrl = 'https://www.7-zip.org/a/7z$sevenZipVersion-x64.exe';
const winMsiUrl = 'https://www.7-zip.org/a/7z$sevenZipVersion-x64.msi';

Directory packageRoot() {
  final script = File(Platform.script.toFilePath());
  return script.parent.parent;
}

Future<void> main() async {
  final root = packageRoot();
  stdout.writeln('DicomFlow 7-Zip fetch → ${root.path}');
  final cache = Directory(p.join(root.path, 'third_party', '7zip'))
    ..createSync(recursive: true);

  String? mac7zz;
  if (Platform.isMacOS || Platform.environment['FETCH_MACOS'] == '1') {
    mac7zz = await _fetchMacos(root, cache);
  }
  await _fetchWindows(root, cache, mac7zz: mac7zz);
  stdout.writeln('Done. Binaries are gitignored; rebuild the app to bundle them.');
}

Future<String?> _fetchMacos(Directory root, Directory cache) async {
  final tarxz = File(p.join(cache.path, '7z$sevenZipVersion-mac.tar.xz'));
  await _download(macUrl, tarxz);
  final unpack = Directory(p.join(cache.path, 'darwin'))..createSync(recursive: true);
  final tar = Process.runSync('tar', ['-xJf', tarxz.path, '-C', unpack.path]);
  if (tar.exitCode != 0) {
    throw StateError('tar failed: ${tar.stderr}');
  }
  final src = File(p.join(unpack.path, '7zz'));
  if (!src.existsSync()) {
    throw StateError('macOS 7-Zip archive has no 7zz');
  }
  final destDir = Directory(p.join(root.path, 'macos', 'Runner', 'Resources'))
    ..createSync(recursive: true);
  final out = File(p.join(destDir.path, '7zz'));
  src.copySync(out.path);
  Process.runSync('chmod', ['+x', out.path]);
  Process.runSync('codesign', ['--force', '--sign', '-', out.path]);
  stdout.writeln('macOS bundled 7zz (${out.lengthSync()} bytes)');
  return out.path;
}

Future<void> _fetchWindows(Directory root, Directory cache, {String? mac7zz}) async {
  final dest = Directory(p.join(root.path, 'windows', 'runner', 'resources', '7zip'))
    ..createSync(recursive: true);
  File? exe;
  File? dll;

  if (mac7zz != null && File(mac7zz).existsSync()) {
    final installer = File(p.join(cache.path, '7z$sevenZipVersion-x64.exe'));
    await _download(winExeUrl, installer);
    final unpack = Directory(p.join(cache.path, 'windows-x64'))..createSync(recursive: true);
    final r = Process.runSync(mac7zz, [
      'x',
      '-y',
      '-o${unpack.path}',
      installer.path,
      '7z.exe',
      '7z.dll',
    ]);
    if (r.exitCode != 0) {
      stdout.writeln('7zz extract of Windows installer failed: ${r.stderr}\n${r.stdout}');
    }
    exe = File(p.join(unpack.path, '7z.exe'));
    dll = File(p.join(unpack.path, '7z.dll'));
  }

  if ((exe == null || !exe.existsSync()) && Platform.isWindows) {
    final msi = File(p.join(cache.path, '7z$sevenZipVersion-x64.msi'));
    await _download(winMsiUrl, msi);
    final unpack = Directory(p.join(cache.path, 'windows-msi'))..createSync(recursive: true);
    final r = Process.runSync('msiexec', [
      '/a',
      msi.path,
      '/qn',
      'TARGETDIR=${unpack.path}',
    ]);
    if (r.exitCode != 0) {
      stdout.writeln('msiexec failed (${r.exitCode}): ${r.stderr}\n${r.stdout}');
    }
    exe = _findFile(unpack, '7z.exe');
    dll = _findFile(unpack, '7z.dll');
  }

  if (exe == null || !exe.existsSync() || dll == null || !dll.existsSync()) {
    stdout.writeln('Windows 7-Zip download skipped (need macOS 7zz or Windows msiexec).');
    return;
  }
  exe.copySync(p.join(dest.path, '7z.exe'));
  dll.copySync(p.join(dest.path, '7z.dll'));
  stdout.writeln('Windows bundled 7z.exe (${exe.lengthSync()} bytes) + 7z.dll (${dll.lengthSync()} bytes)');
}

File? _findFile(Directory root, String name) {
  if (!root.existsSync()) return null;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && p.basename(entity.path).toLowerCase() == name.toLowerCase()) {
      return entity;
    }
  }
  return null;
}

Future<void> _download(String url, File dest) async {
  dest.parent.createSync(recursive: true);
  if (dest.existsSync() && dest.lengthSync() > 100000) {
    stdout.writeln('cached ${p.basename(dest.path)}');
    return;
  }
  stdout.writeln('GET $url');
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
