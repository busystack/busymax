/// The supported ordinal patterns used by every native recurrence editor.
typedef RecurrenceOrdinalChoice = ({String key, List<String> days});

const recurrenceOrdinalChoices = <RecurrenceOrdinalChoice>[
  (key: 'MO', days: ['MO']),
  (key: 'TU', days: ['TU']),
  (key: 'WE', days: ['WE']),
  (key: 'TH', days: ['TH']),
  (key: 'FR', days: ['FR']),
  (key: 'SA', days: ['SA']),
  (key: 'SU', days: ['SU']),
  (key: 'day', days: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']),
  (key: 'weekday', days: ['MO', 'TU', 'WE', 'TH', 'FR']),
  (key: 'weekend', days: ['SA', 'SU']),
];

String recurrenceOrdinalChoiceKey(List<String> days) {
  for (final choice in recurrenceOrdinalChoices) {
    if (days.length == choice.days.length &&
        days.toSet().length == days.length &&
        days.toSet().containsAll(choice.days)) {
      return choice.key;
    }
  }
  return days.firstOrNull ?? 'MO';
}
