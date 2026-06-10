import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';

class BusyMaxTaskRow extends StatelessWidget {
  const BusyMaxTaskRow({
    super.key,
    required this.title,
    required this.completed,
    required this.selected,
    required this.checkbox,
    this.metadata,
    this.trailing,
    this.depth = 0,
    this.onTap,
  });

  final String title;
  final bool completed;
  final bool selected;
  final Widget checkbox;
  final String? metadata;
  final Widget? trailing;
  final int depth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    final metadataStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      decoration: completed ? TextDecoration.lineThrough : null,
    );

    final content = YaruSelectableContainer(
      selected: selected,
      onTap: onTap,
      padding: EdgeInsets.zero,
      selectionColor: Theme.of(context).listTileTheme.selectedTileColor,
      child: YaruListTile.square(
        leading: Align(alignment: Alignment.topCenter, child: checkbox),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: metadata == null || metadata!.isEmpty
            ? null
            : Text(
                metadata!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metadataStyle,
              ),
        trailing: trailing,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: BusyMaxSpacing.sm + depth * 22,
        right: BusyMaxSpacing.sm,
        top: BusyMaxSpacing.xxs,
        bottom: BusyMaxSpacing.xxs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BusyMaxSizes.taskRowMinHeight,
        ),
        child: content,
      ),
    );
  }
}
