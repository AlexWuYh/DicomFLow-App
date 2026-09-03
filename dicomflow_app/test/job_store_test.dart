import 'dart:io';

import 'package:dicomflow_app/domain/job.dart';
import 'package:dicomflow_app/history/job_store.dart';
import 'package:dicomflow_app/history/jobs_controller.dart';
import 'package:dicomflow_app/history/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('displayTitle uses source filename and never stays blank', () {
    expect(
      JobRecord(
        id: '1',
        createdAt: DateTime.utc(2026, 9, 1),
        status: 'SUCCEEDED',
        sourceFilename: 'C252708.rar',
      ).displayTitle,
      'C252708.rar',
    );
    expect(
      JobRecord(
        id: '2',
        createdAt: DateTime.utc(2026, 9, 1),
        status: 'SUCCEEDED',
        sourceFilename: '  ',
        outputs: const [
          JobOutput(
            name: '001_Scout.mp4',
            path: '/tmp/a.mp4',
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ).displayTitle,
      '001_Scout.mp4',
    );
    expect(
      JobRecord(
        id: '3',
        createdAt: DateTime.utc(2026, 9, 1),
        status: 'FAILED',
        sourceFilename: '',
      ).displayTitle,
      '未命名转换',
    );
  });

  test('upsert persists and reloads jobs without patient fields', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/jobs.json');
    final store = JobStore(file);
    await store.load();
    expect(store.jobs, isEmpty);

    final now = DateTime.now();
    await store.upsert(
      JobRecord(
        id: '1',
        createdAt: now.subtract(const Duration(hours: 2)),
        completedAt: now.subtract(const Duration(hours: 1)),
        status: 'SUCCEEDED',
        sourceFilename: 'study.zip',
        outputs: const [
          JobOutput(
            name: '001_Bone.mp4',
            path: '/tmp/001_Bone.mp4',
            sizeBytes: 12,
            frameCount: 5,
            fps: 10,
          ),
        ],
      ),
    );

    final reload = JobStore(file);
    await reload.load();
    expect(reload.jobs, hasLength(1));
    await store.upsert(
      JobRecord(
        id: '0',
        createdAt: now.subtract(const Duration(days: 1)),
        status: 'FAILED',
        sourceFilename: 'older.zip',
      ),
    );
    expect(store.jobs.first.sourceFilename, 'study.zip');
    expect(store.jobs.last.sourceFilename, 'older.zip');
    expect(reload.jobs.single.sourceFilename, 'study.zip');
    expect(reload.jobs.single.outputs.single.frameCount, 5);
    expect(reload.jobs.single.outputs.single.width, 0);
    final raw = file.readAsStringSync();
    expect(raw, isNot(contains('PatientName')));
    expect(raw, isNot(contains('PatientID')));
  });

  test('delete removes job and output files', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_del_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final media = File('${dir.path}/out/001.mp4')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final store = JobStore(File('${dir.path}/jobs.json'));
    final job = JobRecord(
      id: '9',
      createdAt: DateTime.now(),
      status: 'SUCCEEDED',
      sourceFilename: 'a.zip',
      outputs: [
        JobOutput(
          name: '001.mp4',
          path: media.path,
          sizeBytes: 3,
          frameCount: 1,
          fps: 10,
        ),
      ],
    );
    await store.upsert(job);
    await store.delete(job, deleteFiles: true);
    expect(store.jobs, isEmpty);
    expect(media.existsSync(), isFalse);
  });

  test('delete wipes the whole job-id output directory', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_id_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final outDir = Directory('${dir.path}/9')..createSync(recursive: true);
    final media = File('${outDir.path}/001.mp4')..writeAsBytesSync([1, 2, 3]);
    File('${outDir.path}/_work/x.dcm')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([9]);
    final store = JobStore(File('${dir.path}/jobs.json'));
    final job = JobRecord(
      id: '9',
      createdAt: DateTime.now(),
      status: 'FAILED',
      sourceFilename: 'a.zip',
      outputs: [
        JobOutput(
          name: '001.mp4',
          path: media.path,
          sizeBytes: 3,
          frameCount: 1,
          fps: 10,
        ),
      ],
    );
    await store.upsert(job);
    await store.delete(job, deleteFiles: true);
    expect(outDir.existsSync(), isFalse);
  });

  test('load and upsert drop jobs older than 7 days and delete files', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_ttl_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final now = DateTime(2026, 9, 1, 12);
    final oldMedia = File('${dir.path}/old/001.mp4')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const [1]);
    final newMedia = File('${dir.path}/new/001.mp4')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const [2]);
    final store = JobStore(File('${dir.path}/jobs.json'));
    await store.upsert(
      JobRecord(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 8)),
        status: 'SUCCEEDED',
        sourceFilename: 'old.zip',
        outputs: [
          JobOutput(
            name: '001.mp4',
            path: oldMedia.path,
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ),
      now: now,
    );
    await store.upsert(
      JobRecord(
        id: 'fresh',
        createdAt: now.subtract(const Duration(days: 2)),
        status: 'SUCCEEDED',
        sourceFilename: 'fresh.zip',
        outputs: [
          JobOutput(
            name: '001.mp4',
            path: newMedia.path,
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ),
      now: now,
    );
    expect(store.jobs.map((j) => j.id).toList(), ['fresh']);
    expect(oldMedia.existsSync(), isFalse);
    expect(newMedia.existsSync(), isTrue);

    final reload = JobStore(File('${dir.path}/jobs.json'));
    await reload.load(now: now);
    expect(reload.jobs.single.sourceFilename, 'fresh.zip');
  });

  test('normalizeRetentionDays only keeps 1 / 7 / 30', () {
    expect(normalizeRetentionDays(1), 1);
    expect(normalizeRetentionDays(7), 7);
    expect(normalizeRetentionDays(30), 30);
    expect(normalizeRetentionDays(0), 1);
    expect(normalizeRetentionDays(3), 7);
    expect(normalizeRetentionDays(20), 30);
    expect(retentionLabel(1), '1天');
    expect(retentionLabel(7), '7天');
    expect(retentionLabel(30), '30天');
    expect(retentionOptionHint(7), contains('默认'));
  });

  test('countExpired does not delete files', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_count_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final now = DateTime(2026, 9, 3, 12);
    final media = File('${dir.path}/old.mp4')..writeAsBytesSync(const [1]);
    final store = JobStore(File('${dir.path}/jobs.json'));
    await store.upsert(
      JobRecord(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 2)),
        status: 'SUCCEEDED',
        sourceFilename: 'old.zip',
        outputs: [
          JobOutput(
            name: 'old.mp4',
            path: media.path,
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ),
      now: now,
    );
    expect(store.countExpired(const Duration(days: 1), now: now), 1);
    expect(store.countExpired(const Duration(days: 7), now: now), 0);
    expect(store.jobs, hasLength(1));
    expect(media.existsSync(), isTrue);
  });

  test('JobsController setRetentionDays prunes only when applied', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_ctrl_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final now = DateTime(2026, 9, 3, 12);
    final media = File('${dir.path}/old.mp4')..writeAsBytesSync(const [1]);
    final store = JobStore(File('${dir.path}/jobs.json'));
    await store.upsert(
      JobRecord(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 2)),
        status: 'SUCCEEDED',
        sourceFilename: 'old.zip',
        outputs: [
          JobOutput(
            name: 'old.mp4',
            path: media.path,
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ),
      now: now,
    );
    final jobs = JobsController(
      store: store,
      settingsFile: File('${dir.path}/settings.json'),
    );
    expect(jobs.retentionDays, 7);
    expect(jobs.expiredCountFor(1, now: now), 1);
    expect(media.existsSync(), isTrue);
    await jobs.setRetentionDays(1, now: now);
    expect(jobs.retentionDays, 1);
    expect(jobs.jobs, isEmpty);
    expect(media.existsSync(), isFalse);
  });

  test('1-day retention drops jobs older than one day', () async {
    final dir = Directory.systemTemp.createTempSync('dicomflow_jobs_1d_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final now = DateTime(2026, 9, 3, 12);
    final media = File('${dir.path}/old.mp4')..writeAsBytesSync(const [1]);
    final store = JobStore(File('${dir.path}/jobs.json'), retention: const Duration(days: 1));
    await store.upsert(
      JobRecord(
        id: 'old',
        createdAt: now.subtract(const Duration(days: 2)),
        status: 'SUCCEEDED',
        sourceFilename: 'old.zip',
        outputs: [
          JobOutput(
            name: 'old.mp4',
            path: media.path,
            sizeBytes: 1,
            frameCount: 1,
            fps: 10,
          ),
        ],
      ),
      now: now,
    );
    expect(store.jobs, isEmpty);
    expect(media.existsSync(), isFalse);
  });
}
