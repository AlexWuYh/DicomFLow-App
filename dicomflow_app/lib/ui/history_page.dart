import 'package:flutter/material.dart';

import '../domain/job.dart';
import '../history/jobs_controller.dart';
import '../history/settings.dart';
import 'job_detail_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/workspace.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.jobs});

  final JobsController jobs;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部历史？'),
        content: const Text('会删除所有转换记录和对应的结果文件，且无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) await jobs.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return AnimatedBuilder(
      animation: jobs,
      builder: (context, _) {
        final list = jobs.jobs;
        final days = jobs.retentionDays;
        return Scaffold(
          appBar: AppBar(
            title: Text(list.isEmpty ? '历史' : '历史 · ${list.length}'),
            actions: [
              IconButton(
                tooltip: '设置',
                onPressed: () => openSettingsPage(context, jobs),
                icon: const Icon(Icons.settings_outlined),
              ),
              if (list.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context),
                  child: const Text('清空'),
                ),
            ],
          ),
          body: Column(
            children: [
              _RetentionEntry(
                days: days,
                onOpenSettings: () => openSettingsPage(context, jobs),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconWell(icon: Icons.history, size: 72, iconSize: 34),
                              const SizedBox(height: 18),
                              Text(
                                '还没有转换记录',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '转换完成后会出现在这里，可再预览、分享或删除。',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: tokens.muted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, AppLayout.listBottomInset(context)),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = list[index];
                          return _JobTile(
                            job: job,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => JobDetailPage(job: job, jobs: jobs),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RetentionEntry extends StatelessWidget {
  const _RetentionEntry({required this.days, required this.onOpenSettings});

  final int days;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: WorkspaceCard(
        accent: tokens.accent,
        onTap: onOpenSettings,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tokens.accent.withValues(alpha: 0.16),
              child: Icon(Icons.warning_amber_rounded, color: tokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '记录保留 ${retentionLabel(days)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '过期会从本机删除，点此更改保留时间',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.muted2),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.onOpen});

  final JobRecord job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final failed = job.status != 'SUCCEEDED';
    final missing = !failed && job.outputs.any((o) => o.kind != 'zip' && !o.fileExists);
    final mediaCount = job.outputs.where((o) => o.kind != 'zip').length;
    final subtitle = failed
        ? (job.errorMessage ?? job.errorCode ?? '失败')
        : missing
            ? '结果文件已不在本机'
            : '${job.format.toUpperCase()} · ${_qualityLabel(job.quality)} · $mediaCount 个文件';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      child: ListTile(
        onTap: onOpen,
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: CircleAvatar(
          backgroundColor: (failed ? scheme.error : AppColors.primary).withValues(alpha: 0.12),
          child: Icon(
            failed ? Icons.error_outline : Icons.movie_outlined,
            color: failed ? scheme.error : AppColors.primary,
          ),
        ),
        title: Text(
          job.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.25,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${formatJobTime(job.createdAt)}\n$subtitle',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.muted,
              height: 1.35,
            ),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: tokens.muted2),
      ),
    );
  }
}

String formatJobTime(DateTime time) {
  final local = time.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.month}月${local.day}日 $hh:$mm';
}

String _qualityLabel(String quality) {
  switch (quality) {
    case 'high':
      return '高清';
    case 'medium':
      return '标准';
    case 'low':
      return '流畅';
    default:
      return quality;
  }
}
