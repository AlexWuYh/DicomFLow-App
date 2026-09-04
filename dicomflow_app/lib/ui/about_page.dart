import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../history/jobs_controller.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/brand_mark.dart';

const kAppVersion = '1.0.0';
const kAuthorGithub = 'AlexWuYh';
const kAuthorGithubUrl = 'https://github.com/AlexWuYh';
const kAppRepoUrl = 'https://github.com/AlexWuYh/DicomFLow-App';
const kEngineRepoUrl = 'https://github.com/AlexWuYh/DicomFlow';
const kAuthorAvatarAsset = 'assets/author_github.png';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.jobs});

  final JobsController? jobs;

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return;
      }
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
        return;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return;
      }
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    final theme = Theme.of(context);
    final controller = jobs;
    final desktop = AppLayout.isDesktopShell(context);
    final intro = _introCard(theme, tokens);
    final author = _authorCard(context, tokens);
    final settings = controller == null ? null : _settingsCard(context, tokens, controller);
    final source = _sourceCard(context, tokens);
    final license = _licenseCard(theme, tokens);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 880 : 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, AppLayout.listBottomInset(context)),
            children: [
              _HeroCard(tokens: tokens, theme: theme, compact: desktop),
              const SizedBox(height: 16),
              if (desktop) ...[
                _EqualPair(left: intro, right: author),
                const SizedBox(height: 12),
                _EqualPair(left: settings ?? const SizedBox.shrink(), right: source),
              ] else ...[
                intro,
                const SizedBox(height: 12),
                author,
                if (settings != null) ...[
                  const SizedBox(height: 12),
                  settings,
                ],
                const SizedBox(height: 12),
                source,
              ],
              const SizedBox(height: 12),
              license,
              const SizedBox(height: 20),
              Text(
                '便于沟通查阅，不作诊断依据',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context, DicomFlowTokens tokens, JobsController controller) {
    return _SectionCard(
      title: '应用设置',
      child: _TappableRow(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.tune, color: AppColors.primary),
        ),
        title: '历史保留时间',
        subtitle: '1天 / 7天 / 30天，缩短需确认',
        trailing: Icon(Icons.chevron_right, color: tokens.muted2),
        onTap: () => openSettingsPage(context, controller),
      ),
    );
  }

  Widget _introCard(ThemeData theme, DicomFlowTokens tokens) {
    return _SectionCard(
      title: '简介',
      child: Text(
        '把医院导出的 CT / MRI 压缩包（zip / rar / 7z）在本机转成 MP4 或 GIF，方便发给医生用系统播放器查看。'
        '转换全程离线，不上传影像。便于沟通查阅，不作诊断依据。',
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: tokens.muted),
      ),
    );
  }

  Widget _authorCard(BuildContext context, DicomFlowTokens tokens) {
    return _SectionCard(
      title: '作者',
      child: _TappableRow(
        leading: const _AuthorAvatar(),
        title: '@$kAuthorGithub',
        subtitle: kAuthorGithubUrl,
        onTap: () => _open(context, kAuthorGithubUrl),
      ),
    );
  }

  Widget _sourceCard(BuildContext context, DicomFlowTokens tokens) {
    return _SectionCard(
      title: '开源项目',
      child: Column(
        children: [
          _TappableRow(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.phone_iphone, color: AppColors.primary, size: 20),
            ),
            title: '本应用源码',
            subtitle: kAppRepoUrl,
            onTap: () => _open(context, kAppRepoUrl),
          ),
          const Divider(height: 20),
          _TappableRow(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.code, color: AppColors.primary, size: 20),
            ),
            title: '引擎 DicomFlow',
            subtitle: kEngineRepoUrl,
            onTap: () => _open(context, kEngineRepoUrl),
          ),
        ],
      ),
    );
  }

  Widget _licenseCard(ThemeData theme, DicomFlowTokens tokens) {
    return _SectionCard(
      title: '许可',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dart / Flutter 源码以 MIT License 发布。',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: tokens.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '安装包内捆绑的 FFmpeg（含 libx264）按 GPL-3.0 许可。带编码器分发的应用整体按 GPL-3.0 分发。'
            '不含 FFmpeg 二进制时，源码仍可按 MIT 使用。'
            '桌面 rar / 7z 解压使用捆绑的 7-Zip（LGPL，含 unRAR 限制）。Android 用纯 Dart 解压库，不加载 JNI 7-Zip。',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _EqualPair extends StatelessWidget {
  const _EqualPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.tokens,
    required this.theme,
    this.compact = false,
  });

  final DicomFlowTokens tokens;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = BrandMark(size: compact ? 56 : 72);
    final titles = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DicomFlow',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        ),
        const SizedBox(height: 4),
        Text(
          '影像随手看',
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.muted,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              '版本 $kAppVersion',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.accent.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: compact ? const EdgeInsets.fromLTRB(24, 18, 24, 18) : const EdgeInsets.fromLTRB(24, 24, 24, 22),
        child: compact
            ? Row(
                children: [
                  mark,
                  const SizedBox(width: 18),
                  Expanded(child: titles),
                ],
              )
            : Column(
                children: [
                  mark,
                  const SizedBox(height: 14),
                  titles,
                ],
              ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      key: Key('author-avatar'),
      radius: 22,
      backgroundColor: Color(0x1F2563EB),
      backgroundImage: AssetImage(kAuthorAvatarAsset),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = DicomFlowTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.open_in_new, size: 16, color: tokens.muted2),
          ],
        ),
      ),
    );
  }
}
