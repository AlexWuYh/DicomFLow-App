import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:dicomflow_app/domain/convert_params.dart';
import 'package:dicomflow_app/domain/errors.dart';
import 'package:dicomflow_app/engine/convert_worker.dart';
import 'package:dicomflow_app/engine/encode.dart';
import 'package:dicomflow_app/engine/pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/synthetic_dicom.dart';

void main() {
  test('synthetic slice is parseable uncompressed LE', () {
    final bytes = buildSyntheticSlice(
      studyUid: '1.2.3',
      seriesUid: '1.2.4',
      sopUid: '1.2.5',
      instance: 1,
      storedValue: 50,
    );
    final ds = DicomDataset.fromBytes(bytes);
    expect(ds.rows, 32);
    expect(ds.columns, 32);
    expect(ds.seriesInstanceUid, '1.2.4');
    expect(ds.instanceNumber, 1);
    expect(ds.windowCenter, 100);
    expect(ds.pixelDataBytes, isNotNull);
    expect(ds.pixelDataBytes!.length, 32 * 32 * 2);
  });

  test('zip with no dicom yields NO_DICOM', () async {
    final archiveZip = writeTempZip(
      buildSyntheticSeriesZip(frames: 0),
      name: 'empty.zip',
    );
    // 0 frames still creates an empty archive
    addTearDown(() => archiveZip.parent.deleteSync(recursive: true));
    final out = Directory('${archiveZip.parent.path}/out')..createSync();
    await expectLater(
      convertDicomPackage(input: archiveZip, outputDir: out),
      throwsA(
        isA<EngineException>().having((e) => e.code, 'code', EngineException.noDicom),
      ),
    );
    expect(Directory('${out.path}/_work').existsSync(), isFalse);
  });

  test('background isolate converts 5-frame zip', () async {
    final zip = writeTempZip(buildSyntheticSeriesZip());
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'iso'))..createSync();
    final result = await convertDicomPackageInBackground(input: zip, outputDir: outDir);
    expect(result.series.first.frameCount, 5);
    expect(result.seriesOutputs.first.existsSync(), isTrue);
  });

  test('5-frame synthetic zip converts to mp4 with 5 frames', () async {
    final zip = writeTempZip(buildSyntheticSeriesZip());
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'out'))..createSync();
    final result = await convertDicomPackage(input: zip, outputDir: outDir);
    expect(result.seriesOutputs, hasLength(1));
    expect(result.series.first.frameCount, 5);
    expect(result.fps, 10);
    final mp4 = result.seriesOutputs.first;
    expect(mp4.existsSync(), isTrue);
    expect(mp4.lengthSync(), greaterThan(0));
    expect(probeOrSkip(mp4), 5);
  });

  test('two series produce result.zip', () async {
    final zip = writeTempZip(buildSyntheticSeriesZip(frames: 2, seriesCount: 2));
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'out'))..createSync();
    final result = await convertDicomPackage(input: zip, outputDir: outDir);
    expect(result.series.where((s) => s.kind != 'zip'), hasLength(2));
    expect(result.series.where((s) => s.kind == 'zip'), hasLength(1));
    expect(result.series.last.file.existsSync(), isTrue);
  });

  test('unsupported transfer syntax surfaces in the error message', () async {
    final bytes = buildSyntheticSlice(
      studyUid: '1.2.3',
      seriesUid: '1.2.4',
      sopUid: '1.2.5',
      instance: 1,
      storedValue: 50,
      transferSyntaxUid: '1.2.840.10008.1.2.4.90',
    );
    final archive = Archive();
    archive.add(ArchiveFile.bytes('j2k.dcm', bytes));
    final zip = writeTempZip(ZipEncoder().encodeBytes(archive), name: 'j2k.zip');
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'out'))..createSync();
    await expectLater(
      convertDicomPackage(input: zip, outputDir: outDir),
      throwsA(
        isA<EngineException>().having(
          (e) => e.message,
          'message',
          contains('传输语法'),
        ),
      ),
    );
  });

  test('gif output exists', () async {
    final zip = writeTempZip(buildSyntheticSeriesZip(frames: 3));
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'gif'))..createSync();
    final result = await convertDicomPackage(
      input: zip,
      outputDir: outDir,
      params: const ConvertParams(format: OutputFormat.gif, fps: 8),
    );
    expect(result.series, hasLength(1));
    expect(result.series.first.isGif, isTrue);
    expect(result.series.first.file.lengthSync(), greaterThan(0));
  });

  test('merge inserts black frames between series', () async {
    final zip = writeTempZip(buildSyntheticSeriesZip(frames: 2, seriesCount: 2));
    addTearDown(() {
      if (zip.parent.existsSync()) zip.parent.deleteSync(recursive: true);
    });
    final outDir = Directory(p.join(zip.parent.path, 'merge'))..createSync();
    final result = await convertDicomPackage(
      input: zip,
      outputDir: outDir,
      params: const ConvertParams(merge: true, fps: 10),
    );
    final merged = result.series.firstWhere((s) => s.kind == 'merged');
    // 2 + 4 black (0.4s@10fps) + 2 = 8
    expect(merged.frameCount, 8);
    expect(probeOrSkip(merged.file), 8);
    expect(result.series.where((s) => s.kind == 'zip'), isEmpty);
  });
}

int probeOrSkip(File mp4) {
  try {
    return probeFrameCount(mp4);
  } on EngineException catch (e) {
    fail('ffprobe unavailable or failed: $e');
  }
}
