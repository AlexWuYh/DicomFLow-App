import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dicomflow_app/domain/errors.dart';
import 'package:dicomflow_app/engine/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('zip slip is rejected and dest is cleaned', () async {
    final archive = Archive();
    archive.add(ArchiveFile.bytes('../outside.txt', Uint8List.fromList([1, 2, 3])));
    final zip = ZipEncoder().encodeBytes(archive);
    final tmp = Directory.systemTemp.createTempSync('dicomflow_slip_');
    final zipFile = File('${tmp.path}/bad.zip')..writeAsBytesSync(zip);
    final dest = Directory('${tmp.path}/out');
    await expectLater(
      prepareInput(zipFile, destDir: dest),
      throwsA(
        isA<EngineException>().having(
          (e) => e.code,
          'code',
          EngineException.invalidArchive,
        ),
      ),
    );
    expect(dest.existsSync(), isFalse);
    expect(File('${tmp.path}/outside.txt').existsSync(), isFalse);
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
  });

  test('input over maxInputBytes is ARCHIVE_BOMB before extract', () async {
    final zip = ZipEncoder().encodeBytes(Archive());
    final tmp = Directory.systemTemp.createTempSync('dicomflow_big_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final zipFile = File('${tmp.path}/big.zip')..writeAsBytesSync(zip);
    final dest = Directory('${tmp.path}/out');
    await expectLater(
      prepareInput(zipFile, destDir: dest, maxInput: 1),
      throwsA(
        isA<EngineException>().having((e) => e.code, 'code', EngineException.archiveBomb),
      ),
    );
    expect(dest.existsSync(), isFalse);
  });

  test('unsafe archive names are only path traversal after normalize', () {
    expect(isUnsafeArchiveName('../x'), isTrue);
    expect(isUnsafeArchiveName('foo/../../outside'), isTrue);
    expect(isUnsafeArchiveName('~/.ssh/id'), isTrue);
    expect(isUnsafeArchiveName('/DICOM/a.dcm'), isFalse);
    expect(isUnsafeArchiveName(r'C:\DICOM\a.dcm'), isFalse);
    expect(isUnsafeArchiveName('/etc/passwd'), isFalse);
    expect(isUnsafeArchiveName(r'C:\Windows\x'), isFalse);
    expect(isUnsafeArchiveName('ok/dir/file.dcm'), isFalse);
  });

  test('archiveMemberRelative strips unix root and windows drive', () {
    expect(archiveMemberRelative('/DICOM/a.dcm'), 'DICOM/a.dcm');
    expect(archiveMemberRelative(r'C:\DICOM\a.dcm'), 'DICOM/a.dcm');
    expect(archiveMemberRelative('series/1.dcm'), 'series/1.dcm');
    expect(archiveMemberRelative('../x'), '../x');
    expect(archiveMemberRelative('foo/../../etc/passwd'), '../etc/passwd');
    expect(archiveMemberRelative('/'), isNull);
  });

  test('hospital-style absolute zip members extract inside dest', () async {
    final archive = Archive();
    archive.add(ArchiveFile.bytes('/DICOM/a.dcm', Uint8List.fromList([1, 2, 3])));
    archive.add(ArchiveFile.bytes('series/b.dcm', Uint8List.fromList([4, 5])));
    final zip = ZipEncoder().encodeBytes(archive);
    final tmp = Directory.systemTemp.createTempSync('dicomflow_abs_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final zipFile = File('${tmp.path}/study.zip')..writeAsBytesSync(zip);
    final dest = Directory('${tmp.path}/out');
    final out = await prepareInput(zipFile, destDir: dest);
    expect(File('${out.path}/DICOM/a.dcm').readAsBytesSync(), [1, 2, 3]);
    expect(File('${out.path}/series/b.dcm').readAsBytesSync(), [4, 5]);
  });

  test('extract tree with symlink is rejected', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_link_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final dest = Directory('${tmp.path}/tree')..createSync();
    try {
      Link('${dest.path}/sneak').createSync(tmp.path);
    } on FileSystemException {
      markTestSkipped('this OS does not allow creating symlinks');
      return;
    }
    expect(
      () => assertExtractTreeSafe(dest),
      throwsA(
        isA<EngineException>().having(
          (e) => e.code,
          'code',
          EngineException.invalidArchive,
        ),
      ),
    );
  });

  test('lsar header line is listing noise not zip slip', () {
    final archive = File('/tmp/C252708.rar');
    expect(isArchiveListingNoise('/tmp/C252708.rar: RAR 5', archive), isTrue);
    expect(isArchiveListingNoise('/tmp/C252708.rar', archive), isTrue);
    expect(isArchiveListingNoise('C252708.rar', archive), isTrue);
    expect(
      isArchiveListingNoise('C252708/907760/1.25mm bone+10/-0010-0001.DCM', archive),
      isFalse,
    );
    expect(isUnsafeArchiveName('/tmp/C252708.rar: RAR 5'), isFalse);
  });

  test('relativeInside uses canonical paths across /var symlink', () {
    final tmp = Directory.systemTemp.createTempSync('dicomflow_canon_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final nested = Directory(p.join(tmp.path, 'C252708', 'series'))..createSync(recursive: true);
    final file = File(p.join(nested.path, '-0010.DCM'))..writeAsBytesSync(const [1]);
    expect(relativeInside(tmp.path, file.path), p.join('C252708', 'series', '-0010.DCM'));
  });

  test('empty zip is not a bomb, just empty dest', () async {
    final zip = ZipEncoder().encodeBytes(Archive());
    final tmp = Directory.systemTemp.createTempSync('dicomflow_empty_');
    final zipFile = File('${tmp.path}/empty.zip')..writeAsBytesSync(zip);
    final dest = Directory('${tmp.path}/out');
    final out = await prepareInput(zipFile, destDir: dest);
    expect(out.existsSync(), isTrue);
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
  });
}
