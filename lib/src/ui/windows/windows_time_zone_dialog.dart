import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../core/time/time_zone_catalog.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';

Future<String?> showWindowsTimeZoneDialog(
  BuildContext context, {
  required String selectedTimeZone,
}) async {
  final search = TextEditingController();
  var selected = selectedTimeZone;
  var results = <BusyMaxTimeZoneLocation>[];
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return ContentDialog(
          title: Text(l10n.selectTimeZone),
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextBox(
                controller: search,
                autofocus: true,
                placeholder: l10n.searchLocations,
                prefix: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.search)),
                ),
                onChanged: (query) => setState(
                  () => results = BusyMaxTimeZoneCatalog.search(
                    query,
                  ).take(100).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                BusyMaxTimeZoneCatalog.location(selected).displayLabel,
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: results.isEmpty
                    ? Center(child: Text(l10n.noLocationsFound))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final location = results[index];
                          return ListTile.selectable(
                            selected: location.id == selected,
                            title: Text(location.displayLabel),
                            subtitle: Text(
                              '${location.region} · ${location.name}',
                            ),
                            onPressed: () =>
                                setState(() => selected = location.id),
                          );
                        },
                      ),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
  search.dispose();
  return result;
}
