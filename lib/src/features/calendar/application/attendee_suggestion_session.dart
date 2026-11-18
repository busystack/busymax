import '../../../contacts/busymax_contacts_controller.dart';
import '../domain/event_editor_draft.dart';

/// Tracks the active lookup and discards stale results across edits, source
/// changes and contact-scope changes.
final class AttendeeSuggestionSession {
  int _generation = 0;

  void invalidate() => _generation++;

  Future<List<BusyMaxContactSuggestion>?> search({
    required BusyMaxContactsController Function() contacts,
    required String query,
    required String accountId,
    required Iterable<EventAttendeeDraft> attendees,
    required bool Function() isCurrent,
  }) async {
    final generation = ++_generation;
    final term = query.trim();
    if (term.isEmpty) return const [];
    List<BusyMaxContactSuggestion> suggestions;
    try {
      suggestions = await contacts().suggestAttendees(
        term,
        busyMaxAccountId: accountId,
        excludedAddresses: {for (final attendee in attendees) attendee.email},
      );
    } on Object {
      suggestions = const [];
    }
    return generation == _generation && isCurrent() ? suggestions : null;
  }

  Future<bool> accept({
    required BusyMaxContactsController Function() contacts,
    required String accountId,
    required BusyMaxContactSuggestion suggestion,
    required bool Function() isCurrent,
  }) async {
    final generation = _generation;
    try {
      if (!await contacts().suggestionEligible(
        suggestion,
        busyMaxAccountId: accountId,
      )) {
        return false;
      }
    } on Object {
      return false;
    }
    if (generation != _generation || !isCurrent()) return false;
    invalidate();
    return true;
  }
}
