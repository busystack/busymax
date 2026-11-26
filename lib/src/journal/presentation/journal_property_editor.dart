import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../dav/ical/ical_document.dart';
import '../../dav/mutation/dav_mutation_patch.dart';
import '../journal_component.dart';
import 'journal_controls.dart';

const journalDetailsFields = {
  'CLASS',
  'ORGANIZER',
  'URL',
  'COLOR',
  'ATTENDEE',
  'CATEGORIES',
  'COMMENT',
  'CONTACT',
  'RELATED-TO',
  'REQUEST-STATUS',
  'IMAGE',
  'STYLED-DESCRIPTION',
  'STRUCTURED-DATA',
  'LINK',
  'CONCEPT',
  'REFID',
  'RRULE',
  'RDATE',
  'EXDATE',
};
const journalDetailsSingletons = {
  'CLASS',
  'ORGANIZER',
  'URL',
  'COLOR',
  'RRULE',
};

final class JournalPropertyDraft {
  JournalPropertyDraft(
    this.name,
    VoidCallback changed, [
    IcalProperty? original,
  ]) : original = original,
       value = TextEditingController(
         text: _textValue(name, original?.parameters ?? const [])
             ? original?.decodedTextValue
             : original?.rawValue,
       ),
       parameters = [
         for (final parameter
             in original?.parameters ?? const <IcalParameter>[])
           JournalParameterDraft(changed, parameter),
       ] {
    value.addListener(changed);
  }

  final String name;
  final IcalProperty? original;
  final TextEditingController value;
  final List<JournalParameterDraft> parameters;

  IcalProperty toProperty({bool validate = false}) {
    final fields = parameters
        .map((p) => p.parameter(validate: validate))
        .toList();
    final text = _textValue(name, fields);
    final raw =
        (text ? original?.decodedTextValue : original?.rawValue) ==
                value.text &&
            text == _textValue(name, original?.parameters ?? const [])
        ? original!.rawValue
        : text
        ? encodeIcalText(value.text)
        : value.text;
    if (validate && !text && (raw.contains('\r') || raw.contains('\n'))) {
      throw const FormatException('Enter one calendar value per field.');
    }
    final updated = IcalProperty(
      group: original?.group,
      name: name,
      parameters: fields,
      rawValue: raw,
      originalPhysicalLines: const [],
      isDirty: true,
    );
    return updated.serializeLogicalLine() == original?.serializeLogicalLine()
        ? original!
        : updated;
  }

  void dispose() {
    value.dispose();
    for (final parameter in parameters) {
      parameter.dispose();
    }
  }
}

bool _textValue(String name, List<IcalParameter> parameters) {
  final type = parameters
      .where((p) => p.name == 'VALUE')
      .firstOrNull
      ?.values
      .firstOrNull;
  if (type != null) {
    return type.toUpperCase() == 'TEXT' &&
        name != 'CATEGORIES' &&
        name != 'REQUEST-STATUS';
  }
  return const {
    'COMMENT',
    'CONTACT',
    'COLOR',
    'REFID',
    'DESCRIPTION',
    'NAME',
    'SUMMARY',
  }.contains(name);
}

final class JournalParameterDraft {
  JournalParameterDraft(VoidCallback changed, [IcalParameter? original])
    : name = TextEditingController(text: original?.name),
      value = TextEditingController(text: original?.values.join('\n')),
      quoted = original?.wasQuoted ?? false {
    name.addListener(changed);
    value.addListener(changed);
  }

  final TextEditingController name;
  final TextEditingController value;
  final bool quoted;

  IcalParameter parameter({required bool validate}) {
    final token = name.text.trim().toUpperCase();
    if (validate && !RegExp(r'^[A-Z0-9-]+$').hasMatch(token)) {
      throw const FormatException('Enter a valid iCalendar parameter name.');
    }
    return IcalParameter(
      name: token,
      values: value.text.split('\n'),
      wasQuoted: quoted,
    );
  }

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

List<DavPatchOperation> journalDetailsOperations(
  IcalComponent baseline,
  List<IcalProperty> output,
) {
  final changes = <DavPatchOperation>[];
  for (final name in journalDetailsFields) {
    final before = baseline
        .propertiesNamed(name)
        .map((p) => p.serializeLogicalLine())
        .toList();
    final after = output.where((p) => p.name == name).toList();
    if (before.length == after.length &&
        after.indexed.every(
          (item) => item.$2.serializeLogicalLine() == before[item.$1],
        )) {
      continue;
    }
    if (journalDetailsSingletons.contains(name)) {
      if (after.length > 1) {
        // Repeated RRULE is preserved by unrelated edits. Authoring follows the
        // RFC recommendation of a single rule.
        throw const FormatException('Use one value for this journal field.');
      }
      changes.add(
        DavPatchOperation.setRaw(
          name,
          after.firstOrNull?.rawValue,
          parameters: after.firstOrNull?.parameters ?? const [],
        ),
      );
    } else {
      changes.add(
        DavPatchOperation.replaceRepeatedRaw(name, [
          for (final property in after)
            DavRawPropertyValue(
              value: property.rawValue,
              group: property.group,
              parameters: property.parameters,
            ),
        ]),
      );
    }
  }
  return changes;
}

class JournalPropertyEditor extends StatefulWidget {
  const JournalPropertyEditor({
    required this.ui,
    required this.fields,
    required this.changed,
    this.allowedFields = journalDetailsFields,
    this.singletonFields = journalDetailsSingletons,
    super.key,
  });

  final JournalControls ui;
  final List<JournalPropertyDraft> fields;
  final VoidCallback changed;
  final Set<String> allowedFields;
  final Set<String> singletonFields;

  @override
  State<JournalPropertyEditor> createState() => _JournalPropertyEditorState();
}

class _JournalPropertyEditorState extends State<JournalPropertyEditor> {
  String selected = '';

  void update(VoidCallback operation) {
    setState(operation);
    widget.changed();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final l10n = AppLocalizations.of(context);
    final choices = widget.allowedFields
        .where(
          (name) =>
              !widget.singletonFields.contains(name) ||
              !widget.fields.any((field) => field.name == name),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in widget.fields) ...[
          const SizedBox(height: 12),
          if (isDerivedJournalProperty(field.original))
            Text(field.original!.serializeLogicalLine())
          else
            KeyedSubtree(
              key: ObjectKey(field),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ui.input(field.name, controller: field.value),
                  for (final parameter in field.parameters)
                    KeyedSubtree(
                      key: ObjectKey(parameter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ui.input(
                            l10n.journalParameterName,
                            controller: parameter.name,
                          ),
                          ui.input(
                            l10n.journalParameterValues,
                            controller: parameter.value,
                            lines: 2,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ui.button(
                              l10n.removeAction,
                              () => update(() {
                                field.parameters.remove(parameter);
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => parameter.dispose(),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ui.button(
                        l10n.journalAddParameter,
                        () => update(
                          () => field.parameters.add(
                            JournalParameterDraft(widget.changed),
                          ),
                        ),
                      ),
                      ui.button(
                        l10n.removeAction,
                        () => update(() {
                          widget.fields.remove(field);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => field.dispose(),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ui.choose(
              l10n.journalDetailField,
              choices.contains(selected) ? selected : '',
              [
                (id: '', label: '—'),
                for (final name in choices) (id: name, label: name),
              ],
              (name) => setState(() => selected = name),
            ),
            ui.button(
              l10n.journalAddField,
              !choices.contains(selected)
                  ? null
                  : () => update(() {
                      widget.fields.add(
                        JournalPropertyDraft(selected, widget.changed),
                      );
                      selected = '';
                    }),
            ),
          ],
        ),
      ],
    );
  }
}
