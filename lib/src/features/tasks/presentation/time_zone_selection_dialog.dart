import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../core/time/time_zone_catalog.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/native_dialog_service.dart';

const _timeZoneDialogContentHeight = 420.0;

Future<String?> showBusyMaxTimeZoneSelectionDialog(
  BuildContext context, {
  required String selectedTimeZone,
}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    await BusyMaxTimeZoneCatalog.prepareLocationSearch();
    if (!context.mounted) {
      return null;
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final nativeResult = await const NativeDialogService().selectTimeZone(
      title: l10n.selectTimeZone,
      searchPlaceholder: l10n.searchLocations,
      noResultsLabel: l10n.noLocationsFound,
      selectedTimeZone: selectedTimeZone,
      options: [
        for (final result in BusyMaxTimeZoneCatalog.preparedLocationOptions)
          NativeTimeZoneOption(
            id: result.location.id,
            region: result.location.region,
            name: result.name,
            englishName: result.englishName ?? result.name,
            title: result.title,
            subtitle: result.subtitle,
            searchText: result.searchText,
          ),
      ],
      groupedListStyle: NativeGroupedListStyle(
        surfaceColor: busyMaxGroupedSurfaceColor(context),
        dividerColor: surfaceColors.cardShade,
        sectionHeaderColor: theme.colorScheme.onSurfaceVariant,
        primaryTextColor: theme.colorScheme.onSurface,
        secondaryTextColor: surfaceColors.mutedForeground,
        hoverColor: busyMaxRowHoverColor(context),
        shadowColor:
            CardTheme.of(context).shadowColor ?? theme.colorScheme.shadow,
        outlineColor: theme.colorScheme.outline,
        highContrast: MediaQuery.highContrastOf(context),
        radius: BusyMaxRadius.md.round(),
        sectionTopSpacing: BusyMaxSpacing.lg.round(),
        sectionHorizontalPadding: BusyMaxSpacing.xs.round(),
        titleBottomSpacing: BusyMaxSpacing.sm.round(),
      ),
    );
    if (nativeResult.available) {
      return nativeResult.selectedTimeZone;
    }
    if (!context.mounted) {
      return null;
    }
  }

  return showBusyMaxModalDialog<String>(
    context,
    builder: (dialogContext) =>
        BusyMaxTimeZoneSelectionDialog(selectedTimeZone: selectedTimeZone),
  );
}

class BusyMaxTimeZoneSelectionDialog extends StatefulWidget {
  const BusyMaxTimeZoneSelectionDialog({
    super.key,
    required this.selectedTimeZone,
  });

  final String selectedTimeZone;

  @override
  State<BusyMaxTimeZoneSelectionDialog> createState() =>
      _BusyMaxTimeZoneSelectionDialogState();
}

class _BusyMaxTimeZoneSelectionDialogState
    extends State<BusyMaxTimeZoneSelectionDialog> {
  final _searchController = TextEditingController();
  final _resultsController = ScrollController();
  var _query = '';
  var _searchGeneration = 0;
  var _isSearching = false;
  List<BusyMaxTimeZoneSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    unawaited(BusyMaxTimeZoneCatalog.prepareLocationSearch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _resultsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = <String, List<BusyMaxTimeZoneSearchResult>>{};
    for (final result in _results) {
      sections.putIfAbsent(result.location.region, () => []).add(result);
    }

    return BusyMaxDialogShell(
      title: l10n.selectTimeZone,
      maxWidth: 520,
      header: BusyMaxDialogTitleBar(
        title: Text(
          l10n.selectTimeZone,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      children: [
        SizedBox(
          key: const ValueKey('timezone-dialog-content'),
          height: _timeZoneDialogContentHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BusyMaxSearchField(
                controller: _searchController,
                hintText: l10n.searchLocations,
                autofocus: true,
                onChanged: _search,
                onClear: () => _search(''),
              ),
              const SizedBox(height: BusyMaxSpacing.md),
              Expanded(
                child: _isSearching
                    ? const Center(child: YaruCircularProgressIndicator())
                    : _results.isEmpty
                    ? _query.trim().isEmpty
                          ? const SizedBox.shrink()
                          : Center(
                              child: Text(
                                l10n.noLocationsFound,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            )
                    : Scrollbar(
                        controller: _resultsController,
                        thumbVisibility: true,
                        child: ListView(
                          key: const ValueKey('timezone-results-list'),
                          controller: _resultsController,
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final section in sections.entries)
                              BusyMaxGroupedList(
                                title: section.key,
                                filled: true,
                                children: [
                                  for (final result in section.value)
                                    BusyMaxActionRow(
                                      title: result.title,
                                      subtitle: result.subtitle,
                                      leading: const Icon(
                                        Icons.public,
                                        size: BusyMaxSizes.iconSm,
                                      ),
                                      trailing:
                                          result.location.id ==
                                              widget.selectedTimeZone
                                          ? const Icon(
                                              YaruIcons.checkmark,
                                              size: BusyMaxSizes.iconSm,
                                            )
                                          : null,
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pop(result.location.id),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _search(String query) {
    final generation = ++_searchGeneration;
    final hasQuery = query.trim().isNotEmpty;
    if (!hasQuery || BusyMaxTimeZoneCatalog.isLocationSearchReady) {
      setState(() {
        _query = query;
        _isSearching = false;
        _results = hasQuery
            ? BusyMaxTimeZoneCatalog.searchPreparedLocations(query)
            : const [];
      });
      _resetResultsScroll();
      return;
    }

    setState(() {
      _query = query;
      _isSearching = true;
    });
    unawaited(_searchAfterLoad(query, generation));
  }

  Future<void> _searchAfterLoad(String query, int generation) async {
    final results = await BusyMaxTimeZoneCatalog.searchLocations(query);
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    setState(() {
      _results = results;
      _isSearching = false;
    });
    _resetResultsScroll();
  }

  void _resetResultsScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _resultsController.hasClients) {
        _resultsController.jumpTo(0);
      }
    });
  }
}
