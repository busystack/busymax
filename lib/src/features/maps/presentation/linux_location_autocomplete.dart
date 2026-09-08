import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../application/location_search_controller.dart';
import '../data/geoapify_client.dart';
import '../domain/location_result.dart';

class LinuxLocationAutocomplete extends ConsumerStatefulWidget {
  const LinuxLocationAutocomplete({
    super.key,
    required this.text,
    required this.enabled,
    required this.onChanged,
    required this.onPreview,
    this.labelText,
    this.previewAvailable = false,
  });

  final String text;
  final bool enabled;
  final void Function(String text, LocationChange change) onChanged;
  final Future<void> Function() onPreview;
  final String? labelText;
  final bool previewAvailable;

  @override
  ConsumerState<LinuxLocationAutocomplete> createState() =>
      _LinuxLocationAutocompleteState();
}

class _LinuxLocationAutocompleteState
    extends ConsumerState<LinuxLocationAutocomplete> {
  late final TextEditingController _textController;
  LocationSearchController? _search;
  final _focusNode = FocusNode(debugLabel: 'Location search');
  var _highlighted = -1;
  var _programmaticTextUpdate = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
  }

  LocationSearchController? _ensureSearch() {
    if (_search case final existing?) return existing;
    // Some reusable editor widget tests intentionally omit the application
    // composition root. Free-text editing must remain available in that case;
    // production lookup is resolved lazily on the first user search.
    GeoapifyClient client;
    try {
      client = ref.read(geoapifyClientProvider);
    } on StateError {
      return null;
    }
    return _search = LocationSearchController(client)
      ..addListener(_searchChanged);
  }

  @override
  void didUpdateWidget(covariant LinuxLocationAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _textController.text) return;
    _programmaticTextUpdate = true;
    _textController.value = TextEditingValue(
      text: widget.text,
      selection: TextSelection.collapsed(offset: widget.text.length),
    );
    _programmaticTextUpdate = false;
    _search?.clear();
  }

  void _searchChanged() {
    if (!mounted) return;
    setState(() {
      if (_highlighted >= (_search?.results.length ?? 0)) _highlighted = -1;
    });
  }

  void _typed(String value) {
    if (_programmaticTextUpdate) return;
    widget.onChanged(value, const LocationChange.clear());
    final composing = _textController.value.composing;
    _ensureSearch()?.search(
      value,
      language: Localizations.localeOf(context).toLanguageTag(),
      composing: composing.isValid && !composing.isCollapsed,
    );
  }

  void _submit(String value) {
    final search = _ensureSearch();
    if (search == null) return;
    if (_highlighted >= 0 && _highlighted < search.results.length) {
      _select(search.results[_highlighted]);
      return;
    }
    search.search(
      value,
      language: Localizations.localeOf(context).toLanguageTag(),
      submit: true,
      autocomplete: false,
    );
  }

  void _select(LocationResult result) {
    _programmaticTextUpdate = true;
    _textController.value = TextEditingValue(
      text: result.label,
      selection: TextSelection.collapsed(offset: result.label.length),
    );
    _programmaticTextUpdate = false;
    _search?.clear();
    _highlighted = -1;
    widget.onChanged(result.label, LocationChange.replace(result));
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    final results = _search?.results ?? const <LocationResult>[];
    if (event is! KeyDownEvent || results.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlighted = (_highlighted + 1).clamp(0, results.length - 1);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlighted = _highlighted <= 0 ? 0 : _highlighted - 1;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && _highlighted >= 0) {
      _select(results[_highlighted]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _search?.clear();
      _highlighted = -1;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _search
      ?..removeListener(_searchChanged)
      ..dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final search = _search;
    final results = search?.results ?? const <LocationResult>[];
    return Focus(
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('location-autocomplete-field'),
            controller: _textController,
            focusNode: _focusNode,
            // Keep the field decoration interactive in read-only detail
            // views so its map action remains keyboard- and pointer-reachable.
            readOnly: !widget.enabled,
            decoration:
                busyMaxGroupedTextFieldDecoration(
                  context,
                  labelText: widget.labelText ?? l10n.location,
                ).copyWith(
                  suffixIcon: YaruIconButton(
                    tooltip: l10n.mapsShow,
                    onPressed:
                        widget.previewAvailable ||
                            _textController.text.isNotEmpty
                        ? () => unawaited(widget.onPreview())
                        : null,
                    icon: const Icon(Icons.map_outlined),
                  ),
                ),
            textInputAction: TextInputAction.search,
            onChanged: widget.enabled ? _typed : null,
            onSubmitted: widget.enabled ? _submit : null,
          ),
          if (results.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  for (var index = 0; index < results.length; index++)
                    YaruListTile(
                      key: ValueKey('location-result-$index'),
                      leading: index == _highlighted
                          ? const Icon(Icons.arrow_right)
                          : const SizedBox(width: 24),
                      title: Text(results[index].label),
                      subtitle: results[index].approximate
                          ? Text(l10n.mapsApproximate)
                          : null,
                      onTap: () => _select(results[index]),
                    ),
                ],
              ),
            ),
          if (_statusMessage(l10n, search?.status ?? LocationLookupStatus.idle)
              case final message?)
            Padding(
              padding: const EdgeInsets.only(top: BusyMaxSpacing.xs),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (search != null)
            Padding(
              padding: const EdgeInsets.only(top: BusyMaxSpacing.xs),
              child: Text(
                l10n.mapsPrivacy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
