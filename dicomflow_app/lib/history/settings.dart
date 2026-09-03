import 'dart:convert';
import 'dart:io';

const defaultRetentionDays = 7;
const maxRetentionDays = 30;
const retentionPresets = [1, 7, 30];

int normalizeRetentionDays(int days) {
  if (retentionPresets.contains(days)) return days;
  if (days <= 1) return 1;
  if (days <= 7) return 7;
  return 30;
}

String retentionLabel(int days) => '$days天';

String retentionOptionHint(int days) {
  switch (days) {
    case 1:
      return '只留最近一天，最省空间';
    case 7:
      return '默认，适合日常查阅';
    case 30:
      return '最长保留';
    default:
      return '超过 ${retentionLabel(days)} 的记录会删除';
  }
}

class AppSettings {
  const AppSettings({this.retentionDays = defaultRetentionDays});

  final int retentionDays;

  Map<String, Object?> toJson() => {'retentionDays': retentionDays};

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final raw = json['retentionDays'];
    final days = raw is int ? raw : defaultRetentionDays;
    return AppSettings(retentionDays: normalizeRetentionDays(days));
  }
}

Future<AppSettings> loadAppSettings(File file) async {
  if (!file.existsSync()) return const AppSettings();
  try {
    final raw = jsonDecode(await file.readAsString());
    if (raw is Map) {
      return AppSettings.fromJson(Map<String, Object?>.from(raw));
    }
  } catch (_) {}
  return const AppSettings();
}

Future<void> saveAppSettings(File file, AppSettings settings) async {
  file.parent.createSync(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    flush: true,
  );
}
