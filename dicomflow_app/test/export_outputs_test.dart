import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dicomflow_app/share/result_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('copyOutputsToDirectory copies files and uniquifies names', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_export_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final srcDir = Directory(p.join(tmp.path, 'src'))..createSync();
    final dest = Directory(p.join(tmp.path, 'dest'));
    final a = File(p.join(srcDir.path, 'series.mp4'))..writeAsBytesSync(const [1, 2, 3]);
    File(p.join(dest.path, 'series.mp4'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const [9]);

    final n = copyOutputsToDirectory([a], dest);
    expect(n, 1);
    expect(File(p.join(dest.path, 'series.mp4')).readAsBytesSync(), [9]);
    expect(File(p.join(dest.path, 'series_1.mp4')).readAsBytesSync(), [1, 2, 3]);
  });

  test('copyOutputsToDirectory skips missing sources', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_export_miss_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final dest = Directory(p.join(tmp.path, 'dest'))..createSync();
    final missing = File(p.join(tmp.path, 'gone.mp4'));
    final present = File(p.join(tmp.path, 'ok.mp4'))..writeAsBytesSync(const [4]);
    expect(copyOutputsToDirectory([missing, present], dest), 1);
    expect(File(p.join(dest.path, 'ok.mp4')).existsSync(), isTrue);
  });

  test('export package filename uses source stem and timestamp', () {
    expect(
      exportPackageFileName(
        sourceFilename: 'C252708.rar',
        now: DateTime(2026, 9, 1, 18, 30, 45),
      ),
      'C252708_20260901_183045.zip',
    );
    expect(
      exportPackageFileName(sourceFilename: '', now: DateTime(2026, 1, 2, 3, 4, 5)),
      'dicomflow_20260102_030405.zip',
    );
  });

  test('exportPackageToDirectory writes one timestamped zip not loose media', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_pkg_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final a = File(p.join(tmp.path, '001_Scout.mp4'))..writeAsBytesSync(const [1, 2]);
    final b = File(p.join(tmp.path, '004_Stnd.mp4'))..writeAsBytesSync(const [3, 4]);
    final dest = Directory(p.join(tmp.path, 'out'));
    final out = exportPackageToDirectory(
      [a, b],
      dest,
      sourceFilename: 'C252708.rar',
      now: DateTime(2026, 9, 1, 18, 30, 45),
    );
    expect(p.basename(out.path), 'C252708_20260901_183045.zip');
    expect(dest.listSync().whereType<File>().length, 1);
    final archive = ZipDecoder().decodeBytes(out.readAsBytesSync());
    expect(
      archive.map((e) => e.name).toSet(),
      {'001_Scout.mp4', '004_Stnd.mp4'},
    );
  });

  test('exportPackageToDirectory reuses existing result.zip bytes', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_pkgzip_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final packed = ZipEncoder().encodeBytes(
      Archive()..add(ArchiveFile.bytes('a.mp4', const [9])),
    );
    final zip = File(p.join(tmp.path, 'result.zip'))..writeAsBytesSync(packed);
    final loose = File(p.join(tmp.path, 'a.mp4'))..writeAsBytesSync(const [1]);
    final dest = Directory(p.join(tmp.path, 'out'));
    final out = exportPackageToDirectory(
      [loose, zip],
      dest,
      sourceFilename: 'study.zip',
      now: DateTime(2026, 2, 3, 4, 5, 6),
    );
    expect(p.basename(out.path), 'study_20260203_040506.zip');
    expect(out.readAsBytesSync(), packed);
  });
}
