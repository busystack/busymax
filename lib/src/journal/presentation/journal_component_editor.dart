import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../dav/ical/ical_document.dart';
import '../../dav/mutation/dav_mutation_patch.dart';
import '../journal_component.dart';
import 'journal_controls.dart';
import 'journal_property_editor.dart';

class JournalChildDraft {
  JournalChildDraft(this.original, VoidCallback changed)
    : fields = [
        for (final property in original.properties)
          if (_editableChildFields(original.name).contains(property.name))
            JournalPropertyDraft(property.name, changed, property),
      ],
      children = [
        for (final child in original.components)
          JournalChildDraft(child, changed),
      ];

  factory JournalChildDraft.create(String type, VoidCallback changed) {
    final component = IcalComponent(
      name: type,
      originalBeginLine: 'BEGIN:$type',
      originalEndLine: 'END:$type',
      children: [
        if (type != 'VSTATUS')
          IcalProperty(
            group: null,
            name: 'UID',
            rawValue: '${const Uuid().v4()}@busymax.local',
            parameters: const [],
            originalPhysicalLines: const [],
            isDirty: true,
          ),
      ],
    );
    final draft = JournalChildDraft(component, changed);
    for (final name in journalChildRequiredFields[type]!) {
      if (component.firstProperty(name) == null) {
        draft.fields.add(JournalPropertyDraft(name, changed));
      }
    }
    return draft;
  }

  final IcalComponent original;
  final List<JournalPropertyDraft> fields;
  final List<JournalChildDraft> children;
  String get name => original.name;

  bool get containsDerived =>
      original.properties.any(isDerivedJournalProperty) ||
      children.any((child) => child.containsDerived);

  IcalComponent toComponent({bool validate = false}) {
    final remainingFields = [...fields];
    final remainingChildren = [...children];
    final updated = <IcalNode>[];
    for (final node in original.children) {
      if (node is IcalProperty &&
          _editableChildFields(name).contains(node.name)) {
        final index = remainingFields.indexWhere(
          (draft) => identical(draft.original, node),
        );
        if (index >= 0) {
          updated.add(
            remainingFields.removeAt(index).toProperty(validate: validate),
          );
        }
      } else if (node is IcalComponent) {
        final index = remainingChildren.indexWhere(
          (draft) => identical(draft.original, node),
        );
        if (index >= 0) {
          updated.add(
            remainingChildren.removeAt(index).toComponent(validate: validate),
          );
        }
      } else {
        updated.add(node.deepCopy());
      }
    }
    final firstChild = updated.indexWhere((node) => node is IcalComponent);
    updated.insertAll(firstChild < 0 ? updated.length : firstChild, [
      for (final field in remainingFields) field.toProperty(validate: validate),
    ]);
    updated.addAll([
      for (final child in remainingChildren)
        child.toComponent(validate: validate),
    ]);
    return IcalComponent(
      name: name,
      originalBeginLine: original.originalBeginLine,
      originalEndLine: original.originalEndLine,
      children: updated,
    );
  }

  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    for (final child in children) {
      child.dispose();
    }
  }
}

Set<String> _editableChildFields(String name) => {
  ...?journalChildRequiredFields[name]?.where((field) => field != 'UID'),
  ...?journalChildOptionalSingletons[name],
  ...?journalChildRepeatableFields[name],
};

Map<String, Object?> journalChildDraftToJson(IcalComponent component) => {
  'name': component.name,
  'children': [
    for (final node in component.children)
      if (node is IcalComponent)
        journalChildDraftToJson(node)
      else if (node is IcalProperty)
        {
          'property': node.name,
          if (!node.isDirty && node.originalPhysicalLines.isNotEmpty)
            'lines': node.originalPhysicalLines,
          ...DavRawPropertyValue(
            value: node.rawValue,
            group: node.group,
            parameters: node.parameters,
          ).toJson(),
        },
  ],
};

IcalComponent journalChildDraftFromJson(Map<String, Object?> json) {
  final type = json['name'] as String;
  return IcalComponent(
    name: type,
    originalBeginLine: 'BEGIN:$type',
    originalEndLine: 'END:$type',
    children: [
      for (final node in (json['children'] as List).cast<Map>())
        if (node['property'] case final String name)
          _propertyFromDraft(name, node.cast<String, Object?>())
        else
          journalChildDraftFromJson(node.cast<String, Object?>()),
    ],
  );
}

IcalProperty _propertyFromDraft(String name, Map<String, Object?> json) {
  final raw = DavRawPropertyValue.fromJson(json);
  final lines = (json['lines'] as List?)?.cast<String>() ?? const <String>[];
  return IcalProperty(
    name: name,
    group: raw.group,
    rawValue: raw.value,
    parameters: raw.parameters,
    originalPhysicalLines: lines,
    isDirty: lines.isEmpty,
  );
}

class JournalComponentEditor extends StatefulWidget {
  const JournalComponentEditor({
    required this.parentType,
    required this.children,
    required this.ui,
    required this.changed,
    super.key,
  });

  final String parentType;
  final List<JournalChildDraft> children;
  final JournalControls ui;
  final VoidCallback changed;

  @override
  State<JournalComponentEditor> createState() => _JournalComponentEditorState();
}

class _JournalComponentEditorState extends State<JournalComponentEditor> {
  String selected = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = widget.ui;
    final types = journalChildTypes[widget.parentType] ?? const <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in widget.children)
          Padding(
            key: ObjectKey(child),
            padding: const EdgeInsetsDirectional.only(start: 12, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(child.name),
                for (final property in child.original.properties)
                  if (!_editableChildFields(child.name).contains(property.name))
                    Text(property.serializeLogicalLine()),
                JournalPropertyEditor(
                  ui: ui,
                  fields: child.fields,
                  changed: widget.changed,
                  allowedFields: _editableChildFields(child.name),
                  singletonFields: {
                    ...?journalChildRequiredFields[child.name],
                    ...?journalChildOptionalSingletons[child.name],
                  },
                ),
                JournalComponentEditor(
                  parentType: child.name,
                  children: child.children,
                  ui: ui,
                  changed: widget.changed,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ui.button(
                    l10n.removeAction,
                    child.containsDerived
                        ? null
                        : () {
                            setState(() => widget.children.remove(child));
                            widget.changed();
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => child.dispose(),
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        if (types.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ui.choose(l10n.journalDetailField, selected, [
                (id: '', label: '—'),
                for (final type in types) (id: type, label: type),
              ], (value) => setState(() => selected = value)),
              ui.button(
                l10n.journalAddField,
                selected.isEmpty
                    ? null
                    : () {
                        setState(() {
                          widget.children.add(
                            JournalChildDraft.create(selected, widget.changed),
                          );
                        });
                        widget.changed();
                      },
              ),
            ],
          ),
      ],
    );
  }
}

Iterable<Widget> journalReadOnlyChildren(IcalComponent component) sync* {
  for (final child in component.components) {
    yield Text(child.name);
    for (final property in child.properties) {
      yield Text(property.serializeLogicalLine());
    }
    yield* journalReadOnlyChildren(child);
  }
}
