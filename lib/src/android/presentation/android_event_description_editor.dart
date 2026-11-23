import 'package:flutter/material.dart';

import '../../features/calendar/presentation/event_description_controller.dart';
import '../../calendar_providers/calendar_description.dart';
import '../../providers/busy_provider.dart';
import '../../l10n/l10n.dart';

class AndroidEventDescriptionEditor extends StatefulWidget {
  const AndroidEventDescriptionEditor({
    super.key,
    required this.provider,
    required this.text,
    required this.contentType,
    required this.html,
    required this.onChanged,
    this.enabled = true,
  });

  final bool enabled;
  final BusyProvider provider;
  final String? text;
  final String? contentType;
  final String? html;
  final ValueChanged<EventDescriptionValue> onChanged;

  @override
  State<AndroidEventDescriptionEditor> createState() =>
      _AndroidEventDescriptionEditorState();
}

class _AndroidEventDescriptionEditorState
    extends State<AndroidEventDescriptionEditor> {
  late final _binding = EventDescriptionBinding(
    richText: widget.provider == BusyProvider.microsoft,
    text: widget.text,
    contentType: widget.contentType,
    html: widget.html,
    onChanged: (value) => widget.onChanged(value),
  );
  RichDescriptionController get _controller => _binding.controller;
  bool get _supportsRichText => _binding.richText;

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_supportsRichText)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                _FormatButton(
                  enabled: widget.enabled,
                  label: context.l10n.formatBoldShortLabel,
                  tooltip: context.l10n.formatBoldTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.bold,
                  ),
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.bold),
                ),
                const SizedBox(width: 4),
                _FormatButton(
                  enabled: widget.enabled,
                  label: context.l10n.formatItalicShortLabel,
                  tooltip: context.l10n.formatItalicTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.italic,
                  ),
                  italic: true,
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.italic),
                ),
                const SizedBox(width: 4),
                _FormatButton(
                  enabled: widget.enabled,
                  label: context.l10n.formatUnderlineShortLabel,
                  tooltip: context.l10n.formatUnderlineTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.underline,
                  ),
                  underline: true,
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.underline),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(labelText: context.l10n.description),
          cursorColor: Theme.of(context).colorScheme.primary,
          selectionControls: materialTextSelectionControls,
          style: Theme.of(context).textTheme.bodyMedium,
          onTap: () => setState(() {}),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  void _toggleStyle(CalendarDescriptionInlineStyle style) {
    setState(() {
      _controller.toggleStyle(style);
    });
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.enabled = true,
    this.italic = false,
    this.underline = false,
  });

  final bool enabled;
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;
  final bool italic;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      isSelected: active,
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        underline
            ? Icons.format_underlined
            : italic
            ? Icons.format_italic
            : Icons.format_bold,
      ),
    );
  }
}
