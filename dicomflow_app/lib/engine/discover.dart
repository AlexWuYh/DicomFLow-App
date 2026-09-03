import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
import 'package:path/path.dart' as p;

import '../domain/errors.dart';

const _skipSuffixes = {
  '.jpg',
  '.jpeg',
  '.png',
  '.mp4',
  '.gif',
  '.zip',
  '.rar',
  '.7z',
  '.txt',
  '.xml',
  '.json',
  '.html',
  '.pdf',
  '.exe',
  '.dll',
};

final _imagePositionTag = DicomTag(0x0020, 0x0032);

class DicomInstance {
  const DicomInstance({
    required this.path,
    required this.instanceNumber,
    required this.seriesUid,
    required this.seriesDescription,
    required this.seriesNumber,
    required this.studyUid,
    required this.studyDate,
    required this.studyTime,
    this.numberOfFrames = 1,
  });

  final File path;
  final double instanceNumber;
  final String seriesUid;
  final String seriesDescription;
  final int seriesNumber;
  final String studyUid;
  final String studyDate;
  final String studyTime;
  final int numberOfFrames;
}

class SeriesGroup {
  SeriesGroup({
    required this.seriesUid,
    required this.seriesDescription,
    required this.seriesNumber,
    required this.studyUid,
    required this.studyDate,
    required this.studyTime,
  });

  final String seriesUid;
  final String seriesDescription;
  final int seriesNumber;
  final String studyUid;
  final String studyDate;
  final String studyTime;
  final List<DicomInstance> instances = [];

  String get safeName {
    final desc = seriesDescription.trim().isEmpty
        ? seriesUid.substring(0, seriesUid.length.clamp(0, 12))
        : seriesDescription.trim();
    var safe = desc.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
    safe = safe.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final num = seriesNumber == 0 ? '000' : seriesNumber.toString().padLeft(3, '0');
    final base = '${num}_${safe.isEmpty ? seriesUid.substring(0, 12) : safe}';
    return base.length <= 120 ? base : base.substring(0, 120);
  }

  String uniqueOutputStem(Set<String> used) {
    final base = safeName;
    if (used.add(base)) return base;
    final uidClean = seriesUid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix = uidClean.length >= 8
        ? uidClean.substring(uidClean.length - 8)
        : (uidClean.isEmpty ? 'dup' : uidClean);
    for (var n = 0; n < 10000; n++) {
      final tag = n == 0 ? suffix : '${suffix}_$n';
      final budget = 120 - 1 - tag.length;
      final prefix = budget <= 0
          ? ''
          : (base.length <= budget ? base : base.substring(0, budget));
      final name = prefix.isEmpty ? tag : '${prefix}_$tag';
      if (used.add(name)) return name;
    }
    throw const EngineException(
      EngineException.convertError,
      '无法生成不冲突的输出文件名',
    );
  }
}

bool _looksLikeDicomPath(File file) {
  final suffix = p.extension(file.path);
  if (suffix.toUpperCase() == '.DCM') return true;
  final lower = suffix.toLowerCase();
  if (lower == '.dicom' || lower == '.ima') return true;
  if (suffix.isEmpty) return true;
  if (_skipSuffixes.contains(lower)) return false;
  if (RegExp(r'^\.\d+$').hasMatch(suffix)) return true;
  return false;
}

double _instanceSortKey(DicomDataset ds) {
  final n = ds.instanceNumber;
  if (n != null) return n.toDouble();
  final ipp = ds.getDoubleList(_imagePositionTag);
  if (ipp != null && ipp.length >= 3) return ipp[2];
  return 0;
}

bool _hasImagePixels(DicomDataset ds) {
  if (ds.pixelDataBytes != null && ds.pixelDataBytes!.isNotEmpty) return true;
  return ds.rows > 0 && ds.columns > 0;
}

DicomDataset? _tryRead(File file) {
  try {
    final bytes = file.readAsBytesSync();
    if (bytes.length < 132) return null;
    final ds = DicomDataset.fromBytes(Uint8List.fromList(bytes));
    if (!_hasImagePixels(ds)) return null;
    return ds;
  } catch (_) {
    return null;
  }
}

List<DicomInstance> findDicomInstances(Directory root) {
  if (!root.existsSync()) {
    throw EngineException(EngineException.noDicom, '目录不存在', detail: root.path);
  }
  final instances = <DicomInstance>[];
  final files = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    if (!_looksLikeDicomPath(file)) continue;
    final ds = _tryRead(file);
    if (ds == null) continue;
    instances.add(
      DicomInstance(
        path: file,
        instanceNumber: _instanceSortKey(ds),
        seriesUid: ds.seriesInstanceUid ?? 'unknown',
        seriesDescription: ds.seriesDescription,
        seriesNumber: ds.seriesNumber ?? 0,
        studyUid: ds.studyInstanceUid ?? 'unknown',
        studyDate: ds.studyDate,
        studyTime: ds.studyTime ?? '',
        numberOfFrames: ds.numberOfFrames < 1 ? 1 : ds.numberOfFrames,
      ),
    );
  }
  return instances;
}

List<SeriesGroup> groupSeries(List<DicomInstance> instances) {
  if (instances.isEmpty) {
    throw const EngineException(EngineException.noDicom, '未找到任何有效 DICOM 图像文件');
  }
  final groups = <String, SeriesGroup>{};
  for (final inst in instances) {
    final g = groups.putIfAbsent(
      inst.seriesUid,
      () => SeriesGroup(
        seriesUid: inst.seriesUid,
        seriesDescription: inst.seriesDescription,
        seriesNumber: inst.seriesNumber,
        studyUid: inst.studyUid,
        studyDate: inst.studyDate,
        studyTime: inst.studyTime,
      ),
    );
    g.instances.add(inst);
  }
  final list = groups.values.toList();
  for (final g in list) {
    g.instances.sort((a, b) {
      final c = a.instanceNumber.compareTo(b.instanceNumber);
      if (c != 0) return c;
      return a.path.path.compareTo(b.path.path);
    });
  }
  list.sort((a, b) {
    final d = a.studyDate.compareTo(b.studyDate);
    if (d != 0) return d;
    final t = a.studyTime.compareTo(b.studyTime);
    if (t != 0) return t;
    final u = a.studyUid.compareTo(b.studyUid);
    if (u != 0) return u;
    final n = a.seriesNumber.compareTo(b.seriesNumber);
    if (n != 0) return n;
    final s = a.seriesDescription.compareTo(b.seriesDescription);
    if (s != 0) return s;
    return a.seriesUid.compareTo(b.seriesUid);
  });
  return list;
}
