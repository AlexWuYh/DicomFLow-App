import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/job.dart';

import 'settings.dart';

/// Local JSON job log. Does not store PatientName / PatientID.
class JobStore {
  JobStore(this.file, {Duration? retention})
      : retention = retention ?? const Duration(days: defaultRetentionDays);

  final File file;
  Duration retention;
  final List<JobRecord> _jobs = [];

  List<JobRecord> get jobs => List.unmodifiable(_jobs);

  Future<void> load({DateTime? now}) async {
    _jobs.clear();
    if (!file.existsSync()) return;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return;
    for (final item in raw) {
      if (item is Map) {
        _jobs.add(JobRecord.fromJson(Map<String, Object?>.from(item)));
      }
    }
    _jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_pruneExpired(now ?? DateTime.now())) {
      await _flush();
    }
  }

  Future<void> upsert(JobRecord job, {DateTime? now}) async {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    } else {
      _jobs.add(job);
    }
    _jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _pruneExpired(now ?? DateTime.now());
    await _flush();
  }

  Future<void> setRetention(Duration value, {DateTime? now}) async {
    retention = value;
    if (_pruneExpired(now ?? DateTime.now())) {
      await _flush();
    }
  }

  /// Jobs that would be dropped if [window] were applied. Does not delete files.
  int countExpired(Duration window, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(window);
    return _jobs.where((job) => job.createdAt.isBefore(cutoff)).length;
  }

  /// Drop jobs older than [retention]. Returns true if anything was removed.
  bool _pruneExpired(DateTime now) {
    final cutoff = now.subtract(retention);
    final expired = [for (final job in _jobs) if (job.createdAt.isBefore(cutoff)) job];
    if (expired.isEmpty) return false;
    for (final job in expired) {
      _jobs.removeWhere((item) => item.id == job.id);
      _deleteOutputs(job);
    }
    return true;
  }

  Future<void> delete(JobRecord job, {bool deleteFiles = true}) async {
    _jobs.removeWhere((j) => j.id == job.id);
    if (deleteFiles) {
      _deleteOutputs(job);
    }
    await _flush();
  }

  Future<void> deleteAll({bool deleteFiles = true}) async {
    if (deleteFiles) {
      for (final job in List<JobRecord>.from(_jobs)) {
        _deleteOutputs(job);
      }
    }
    _jobs.clear();
    await _flush();
  }

  void _deleteOutputs(JobRecord job) {
    final dirs = <String>{};
    for (final out in job.outputs) {
      final f = File(out.path);
      dirs.add(p.normalize(f.parent.path));
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      if (p.basename(dirPath) == job.id) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
        continue;
      }
      if (dir.listSync(followLinks: false).isEmpty) {
        try {
          dir.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> _flush() async {
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert([for (final j in _jobs) j.toJson()]),
      flush: true,
    );
  }
}
