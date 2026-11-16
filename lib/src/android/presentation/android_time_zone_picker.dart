import 'package:flutter/material.dart';

import '../../core/time/time_zone_catalog.dart';
import '../../l10n/l10n.dart';

Future<String?> showAndroidTimeZonePicker(
  BuildContext context,
  String? selected,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _AndroidTimeZonePicker(selected: selected),
);

class _AndroidTimeZonePicker extends StatefulWidget {
  const _AndroidTimeZonePicker({this.selected});
  final String? selected;
  @override
  State<_AndroidTimeZonePicker> createState() => _AndroidTimeZonePickerState();
}

class _AndroidTimeZonePickerState extends State<_AndroidTimeZonePicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final locations = BusyMaxTimeZoneCatalog.locations
        .where((l) => l.matches(_query))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.selectTimeZone,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (query) => setState(() => _query = query),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (_, index) {
                    final location = locations[index];
                    return ListTile(
                      title: Text(location.displayLabel),
                      selected: widget.selected == location.id,
                      onTap: () => Navigator.pop(context, location.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
