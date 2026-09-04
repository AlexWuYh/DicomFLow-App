import 'package:flutter/material.dart';

import '../theme.dart';
import 'workspace.dart';

class PreviewFileItem {
  const PreviewFileItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Compact mobile file switcher: prev/next plus a sheet for the full list.
class PreviewFileSwitcher extends StatelessWidget {
  const PreviewFileSwitcher({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PreviewFileItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  int get _index {
    final i = items.indexWhere((e) => e.id == selectedId);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tokens = DicomFlowTokens.of(context);
    final index = _index;
    final item = items[index];
    final many = items.length > 1;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Row(
          children: [
            IconButton(
              key: const Key('preview-file-prev'),
              tooltip: '上一个文件',
              onPressed: many ? () => _step(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                key: const Key('preview-file-open-list'),
                borderRadius: BorderRadius.circular(AppRadii.control),
                onTap: many ? () => _openSheet(context) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        many ? '文件 ${index + 1} / ${items.length}' : '当前文件',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (many)
              IconButton(
                tooltip: '全部文件',
                onPressed: () => _openSheet(context),
                icon: const Icon(Icons.unfold_more, size: 20),
              ),
            IconButton(
              key: const Key('preview-file-next'),
              tooltip: '下一个文件',
              onPressed: many ? () => _step(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  void _step(int delta) {
    final next = (_index + delta) % items.length;
    onSelected(items[next].id);
  }

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showPreviewFileSheet(
      context: context,
      items: items,
      selectedId: selectedId,
    );
    if (picked != null) onSelected(picked);
  }
}

Future<String?> showPreviewFileSheet({
  required BuildContext context,
  required List<PreviewFileItem> items,
  required String selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final tokens = DicomFlowTokens.of(ctx);
      final maxH = MediaQuery.sizeOf(ctx).height * 0.5;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '选择文件 · ${items.length}',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final on = item.id == selectedId;
                  return WorkspaceCard(
                    selected: on,
                    onTap: () => Navigator.pop(ctx, item.id),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: on ? Theme.of(ctx).colorScheme.primary : tokens.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(ctx).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                item.subtitle,
                                style: TextStyle(color: tokens.muted2, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${index + 1}',
                          style: TextStyle(color: tokens.muted2, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
