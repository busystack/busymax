import '../features/calendar/data/calendar_repository.dart';
import '../providers/busy_provider.dart';
import 'ical_import_service.dart';

bool preservesNativeIcal(BusyProvider? provider) =>
    provider == BusyProvider.nextcloud || provider == BusyProvider.caldav;

final class IcalImportSession {
  IcalImportSession(this.preview, this.destinations)
    : _destination = destinations.firstOrNull;

  final IcalImportPreview preview;
  final List<CalendarSourceEntity> destinations;
  CalendarSourceEntity? _destination;
  bool newCopies = false;
  bool allowScheduling = false;

  CalendarSourceEntity? get destination => _destination;

  set destination(CalendarSourceEntity? target) {
    _destination = target;
    allowScheduling = false;
  }

  bool get native => preservesNativeIcal(destination?.provider);
  bool get schedulingConsentRequired =>
      destination?.provider == BusyProvider.caldav &&
      preview.nativePreview.hasAttendees;

  IcalImportSelection? get selection {
    final selected = destination;
    if (selected == null || (schedulingConsentRequired && !allowScheduling)) {
      return null;
    }
    return IcalImportSelection(
      selected,
      newCopies: native && newCopies,
      allowScheduling: schedulingConsentRequired && allowScheduling,
    );
  }
}

extension SubmitIcalImport on IcalImportService {
  Future<IcalImportReport> importSelection(
    IcalImportPreview preview,
    IcalImportSelection selection,
  ) => importPreview(
    preview: preview,
    destination: selection.destination,
    nativeDuplicates: selection.duplicatePolicy,
    allowScheduling: selection.allowScheduling,
    normalizeNativeSchedulingMethod: preservesNativeIcal(
      selection.destination.provider,
    ),
  );
}
