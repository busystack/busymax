import 'event_description_controller.dart';
export 'event_description_controller.dart' show EventDescriptionValue;

import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../calendar_providers/calendar_description.dart';
import '../../../l10n/l10n.dart';

import 'package:busymax/src/providers/busy_provider.dart';

class EventDescriptionEditor extends StatefulWidget {
  const EventDescriptionEditor({
    super.key,
    required this.provider,
    required this.text,
    required this.contentType,
    required this.html,
    required this.onChanged,
  });

  final BusyProvider provider;
  final String? text;
  final String? contentType;
  final String? html;
  final ValueChanged<EventDescriptionValue> onChanged;

  @override
  State<EventDescriptionEditor> createState() => _EventDescriptionEditorState();
}

class _EventDescriptionEditorState extends State<EventDescriptionEditor> {
  late final RichDescriptionController _controller;
  var _notifying = false;
  late String _lastEmittedText;
  String? _lastEmittedHtml;

  bool get _supportsRichText => widget.provider == BusyProvider.microsoft;

  @override
  void initState() {
    super.initState();
    final document = _supportsRichText && isHtmlContentType(widget.contentType)
        ? htmlCalendarDescriptionDocument(widget.html ?? '')
        : CalendarDescriptionDocument(
            text: widget.text ?? '',
            ranges: const [],
          );
    _controller = RichDescriptionController(document);
    _lastEmittedText = _controller.text;
    _lastEmittedHtml = _supportsRichText
        ? calendarDescriptionToHtml(_controller.text, _controller.ranges)
        : null;
    _controller.addListener(_emitChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_emitChanged)
      ..dispose();
    super.dispose();
  }

  void _emitChanged() {
    if (_notifying) {
      return;
    }
    _notifying = true;
    try {
      final text = _controller.text;
      if (_supportsRichText) {
        final html = calendarDescriptionToHtml(text, _controller.ranges);
        if (text == _lastEmittedText && html == _lastEmittedHtml) return;
        _lastEmittedText = text;
        _lastEmittedHtml = html;
        widget.onChanged(
          EventDescriptionValue(text: text, contentType: 'html', html: html),
        );
        return;
      }
      if (text == _lastEmittedText) return;
      _lastEmittedText = text;
      widget.onChanged(EventDescriptionValue(text: text));
    } finally {
      _notifying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_supportsRichText)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BusyMaxSpacing.sm,
              BusyMaxSpacing.xs,
              BusyMaxSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                _FormatButton(
                  label: context.l10n.formatBoldShortLabel,
                  tooltip: context.l10n.formatBoldTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.bold,
                  ),
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.bold),
                ),
                const SizedBox(width: BusyMaxSpacing.xs),
                _FormatButton(
                  label: context.l10n.formatItalicShortLabel,
                  tooltip: context.l10n.formatItalicTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.italic,
                  ),
                  italic: true,
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.italic),
                ),
                const SizedBox(width: BusyMaxSpacing.xs),
                _FormatButton(
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
          minLines: 4,
          maxLines: 8,
          decoration: _descriptionDecoration(context),
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
    _emitChanged();
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.italic = false,
    this.underline = false,
  });

  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;
  final bool italic;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: BusyMaxSizes.headerIconButton,
        child: BusyMaxHeaderIconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (active || states.contains(WidgetState.hovered)) {
              return surfaceColors.controlHover;
            }
            return Colors.transparent;
          }),
          icon: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: italic ? FontStyle.italic : null,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _descriptionDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: context.l10n.description,
    alignLabelWithHint: true,
    floatingLabelStyle: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant),
    labelStyle: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: true,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: BusyMaxSpacing.sm,
      vertical: BusyMaxSpacing.sm,
    ),
  );
}
