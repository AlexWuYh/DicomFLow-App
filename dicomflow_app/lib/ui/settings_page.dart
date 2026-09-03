import 'package:flutter/material.dart';

import '../history/jobs_controller.dart';
import '../history/settings.dart';
import 'theme.dart';
import 'widgets/workspace.dart';

void openSettingsPage(BuildContext context, JobsController jobs) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SettingsPage(jobs: jobs)),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.jobs});

  final JobsController jobs;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _selected = normalizeRetentionDays(widget.jobs.retentionDays);
  var _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final current = widget.jobs.retentionDays;
    if (_selected == current) return;

    final shortening = _selected < current;
    if (shortening) {
      final expired = widget.jobs.expiredCountFor(_selected);
      final confirmed = await _confirmShorten(expiredCount: expired);
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await widget.jobs.setRetentionDays(_selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存，记录保留 ${retentionLabel(_selected)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmShorten({required int expiredCount}) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(expiredCount > 0 ? '将删除过期记录' : '确认缩短保留时间？'),
        content: Text(
          expiredCount > 0
              ? '改为保留最近 ${retentionLabel(_selected)} 后，会立即删除 $expiredCount 条更早的记录及其结果文件，无法恢复。'
              : '改为保留最近 ${retentionLabel(_selected)} 后，之后超过该天数的记录会自动删除。当前没有需要立即清理的记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: expiredCount > 0 ? scheme.error : null,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(expiredCount > 0 ? '删除过期记录' : '确认保存'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final theme = Theme.of(context);
    final current = widget.jobs.retentionDays;
    final dirty = _selected != current;
    final expiredIfSaved = _selected < current ? widget.jobs.expiredCountFor(_selected) : 0;
    final warningColor = expiredIfSaved > 0 ? theme.colorScheme.error : tokens.accent;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, AppLayout.listBottomInset(context)),
            children: [
              Text(
                '历史记录',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tokens.muted,
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < retentionPresets.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        _RetentionOption(
                          days: retentionPresets[i],
                          selected: _selected == retentionPresets[i],
                          enabled: !_saving,
                          onTap: () => setState(() => _selected = retentionPresets[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              WorkspaceCard(
                accent: warningColor,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      expiredIfSaved > 0 ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: warningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        expiredIfSaved > 0
                            ? '保存后将立即删除 $expiredIfSaved 条过期记录及其结果文件，无法恢复。'
                            : '超过保留天数的记录会连结果文件一起从本机删除，无法恢复。缩短天数时需再次确认才会清理。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: expiredIfSaved > 0 ? theme.colorScheme.error : tokens.muted,
                          fontWeight: expiredIfSaved > 0 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: dirty && !_saving ? _save : null,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
              const SizedBox(height: 10),
              Text(
                '当前生效：${retentionLabel(current)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetentionOption extends StatelessWidget {
  const _RetentionOption({
    required this.days,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = DicomFlowTokens.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? scheme.primary : tokens.muted2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retentionLabel(days),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    retentionOptionHint(days),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
