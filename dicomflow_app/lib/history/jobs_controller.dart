import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/job.dart';
import 'job_store.dart';
import 'paths.dart';
import 'settings.dart';

class JobsController extends ChangeNotifier {
  JobsController({this.store, this.settingsFile});

  JobStore? store;
  File? settingsFile;
  int _retentionDays = defaultRetentionDays;

  List<JobRecord> get jobs => store?.jobs ?? const [];
  int get retentionDays => store?.retention.inDays ?? _retentionDays;

  int expiredCountFor(int days, {DateTime? now}) {
    final current = store;
    if (current == null) return 0;
    return current.countExpired(
      Duration(days: normalizeRetentionDays(days)),
      now: now ?? DateTime.now(),
    );
  }

  Future<JobStore> ensureStore() async {
    final existing = store;
    if (existing != null) return existing;
    settingsFile ??= await defaultSettingsFile();
    final loaded = await loadAppSettings(settingsFile!);
    _retentionDays = loaded.retentionDays;
    final file = await defaultJobsFile();
    final created = JobStore(file, retention: Duration(days: _retentionDays));
    await created.load();
    store = created;
    notifyListeners();
    return created;
  }

  Future<void> setRetentionDays(int days, {DateTime? now}) async {
    final normalized = normalizeRetentionDays(days);
    _retentionDays = normalized;
    settingsFile ??= await defaultSettingsFile();
    await saveAppSettings(settingsFile!, AppSettings(retentionDays: normalized));
    final current = await ensureStore();
    await current.setRetention(Duration(days: normalized), now: now);
    notifyListeners();
  }

  Future<void> upsert(JobRecord job) async {
    final current = await ensureStore();
    await current.upsert(job);
    notifyListeners();
  }

  Future<void> delete(JobRecord job) async {
    final current = await ensureStore();
    await current.delete(job, deleteFiles: true);
    notifyListeners();
  }

  Future<void> clearAll() async {
    final current = await ensureStore();
    await current.deleteAll(deleteFiles: true);
    notifyListeners();
  }
}
