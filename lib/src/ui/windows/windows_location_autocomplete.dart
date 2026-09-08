import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../features/maps/application/location_search_controller.dart';
import '../../features/maps/data/geoapify_client.dart';
import '../../features/maps/domain/location_result.dart';

class WindowsLocationAutocomplete extends StatefulWidget {
  const WindowsLocationAutocomplete({
    super.key,
    required this.controller,
    required this.client,
    required this.enabled,
    required this.onChanged,
    required this.onPreview,
    this.previewAvailable = false,
  });

  final TextEditingController controller;
  final GeoapifyClient client;
  final bool enabled;
  final void Function(String text, LocationChange change) onChanged;
  final Future<void> Function() onPreview;
  final bool previewAvailable;

  @override
  State<WindowsLocationAutocomplete> createState() =>
      _WindowsLocationAutocompleteState();
}

class _WindowsLocationAutocompleteState
    extends State<WindowsLocationAutocomplete> {
  late final LocationSearchController _search;
  final _focusNode = FocusNode(debugLabel: 'Windows location search');
  var _programmaticTextUpdate = false;

  @override
  void initState() {
    super.initState();
    _search = LocationSearchController(widget.client)..addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant WindowsLocationAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      _search.clear();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _textChanged(String value, TextChangedReason reason) {
    if (_programmaticTextUpdate ||
        reason == TextChangedReason.suggestionChosen) {
      return;
    }
    widget.onChanged(value, const LocationChange.clear());
    final composing = widget.controller.value.composing;
    _search.search(
      value,
      language: Localizations.localeOf(context).toLanguageTag(),
      composing: composing.isValid && !composing.isCollapsed,
    );
  }

  void _selected(AutoSuggestBoxItem<LocationResult> item) {
    final result = item.value;
    if (result == null) return;
    _programmaticTextUpdate = true;
    widget.controller.value = TextEditingValue(
      text: result.label,
      selection: TextSelection.collapsed(offset: result.label.length),
    );
    _programmaticTextUpdate = false;
    _search.clear();
    widget.onChanged(result.label, LocationChange.replace(result));
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        _search.results.isEmpty) {
      _search.search(
        widget.controller.text,
        language: Localizations.localeOf(context).toLanguageTag(),
        submit: true,
        autocomplete: false,
      );
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _search.clear();
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _search
      ..removeListener(_changed)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AutoSuggestBox<LocationResult>(
            key: const ValueKey('windows-location-autocomplete-field'),
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            placeholder: l10n.mapsSearch,
            textInputAction: TextInputAction.search,
            sorter: (_, items) => items,
            items: [
              for (final result in _search.results)
                AutoSuggestBoxItem(
                  value: result,
                  label: result.label,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.label),
                      if (result.approximate)
                        Text(
                          l10n.mapsApproximate,
                          style: FluentTheme.of(context).typography.caption,
                        ),
                    ],
                  ),
                ),
            ],
            onChanged: _textChanged,
            onSelected: _selected,
            trailingIcon: Tooltip(
              message: l10n.mapsShow,
              child: IconButton(
                icon: const Icon(FluentIcons.map_pin),
                onPressed:
                    widget.previewAvailable || widget.controller.text.isNotEmpty
                    ? () => unawaited(widget.onPreview())
                    : null,
              ),
            ),
          ),
          if (_statusMessage(l10n, _search.status) case final message?) ...[
            const SizedBox(height: 4),
            Text(message, style: FluentTheme.of(context).typography.caption),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.mapsPrivacy,
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}

String? _statusMessage(AppLocalizations l10n, LocationLookupStatus status) =>
    switch (status) {
      LocationLookupStatus.loading => l10n.mapsLoading,
      LocationLookupStatus.empty => l10n.mapsEmpty,
      LocationLookupStatus.offline => l10n.mapsOffline,
      LocationLookupStatus.unconfigured => l10n.mapsUnconfigured,
      LocationLookupStatus.rateLimited => l10n.mapsRateLimited,
      LocationLookupStatus.failed => l10n.mapsServiceError,
      LocationLookupStatus.idle || LocationLookupStatus.results => null,
    };
