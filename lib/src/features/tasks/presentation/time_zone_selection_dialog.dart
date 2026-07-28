import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../core/time/time_zone_catalog.dart';
import '../../../l10n/l10n.dart';

const _timeZoneDialogContentHeight = 420.0;

Future<String?> showBusyMaxTimeZoneSelectionDialog(
  BuildContext context, {
  required String selectedTimeZone,
}) {
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

  @override
  void dispose() {
    _searchController.dispose();
    _resultsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = BusyMaxTimeZoneCatalog.search(_query);
    final sections = <String, List<BusyMaxTimeZoneLocation>>{};
    for (final location in results) {
      sections.putIfAbsent(location.region, () => []).add(location);
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
                onChanged: (value) => setState(() => _query = value),
                onClear: () => setState(() => _query = ''),
              ),
              const SizedBox(height: BusyMaxSpacing.md),
              Expanded(
                child: results.isEmpty
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
                                  for (final location in section.value)
                                    BusyMaxActionRow(
                                      title:
                                          '${location.name} (${location.code})',
                                      subtitle: location.id,
                                      leading: const Icon(
                                        Icons.public,
                                        size: BusyMaxSizes.iconSm,
                                      ),
                                      trailing:
                                          location.id == widget.selectedTimeZone
                                          ? const Icon(
                                              YaruIcons.checkmark,
                                              size: BusyMaxSizes.iconSm,
                                            )
                                          : null,
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pop(location.id),
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
}
