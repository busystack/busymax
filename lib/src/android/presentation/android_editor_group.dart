import 'package:flutter/material.dart';

import '../../app/busymax_surface_colors.dart';
import '../../l10n/l10n.dart';

/// Native editor container for BusyMax's ordered, conditional field groups.
class AndroidEditorGroup extends StatelessWidget {
  const AndroidEditorGroup({
    super.key,
    this.title,
    this.expanded,
    required this.children,
  });
  final String? title;
  final bool? expanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final fields = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
    final colors = BusyMaxSurfaceColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Color.alphaBlend(colors.groupedSurface, colors.window),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: expanded == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                  fields,
                ],
              )
            : ExpansionTile(
                title: Text(title!),
                initiallyExpanded: expanded!,
                maintainState: true,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [fields],
              ),
      ),
    );
  }
}

/// Category values are edited atomically; punctuation remains part of a value.
class AndroidCategoryEditor extends StatefulWidget {
  const AndroidCategoryEditor({
    super.key,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
  });
  final List<String> values;
  final ValueChanged<List<String>>? onChanged;
  final List<String> suggestions;
  @override
  State<AndroidCategoryEditor> createState() => _AndroidCategoryEditorState();
}

class _AndroidCategoryEditorState extends State<AndroidCategoryEditor> {
  final _input = TextEditingController();
  bool _adding = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String text) {
    final value = text.trim();
    if (value.isEmpty ||
        widget.values.any((v) => v.toLowerCase() == value.toLowerCase())) {
      return;
    }
    widget.onChanged?.call([...widget.values, value]);
    _input.clear();
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.categories,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final value in widget.values)
            InputChip(
              label: Text(value),
              onDeleted: widget.onChanged == null
                  ? null
                  : () => widget.onChanged!([
                      for (final item in widget.values)
                        if (item != value) item,
                    ]),
            ),
        ],
      ),
      if (_adding) ...[
        TextField(
          controller: _input,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.categories),
          onSubmitted: _add,
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: () => _add(_input.text),
              child: Text(context.l10n.addCategory),
            ),
            TextButton(
              onPressed: () => setState(() {
                _input.clear();
                _adding = false;
              }),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final value in widget.suggestions.where(
              (s) => !widget.values.contains(s),
            ))
              ActionChip(label: Text(value), onPressed: () => _add(value)),
          ],
        ),
      ] else if (widget.onChanged != null)
        TextButton.icon(
          onPressed: () => setState(() => _adding = true),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addCategory),
        ),
    ],
  );
}
