import '../../../providers/busy_provider.dart';
import '../../../schedule/schedule_item.dart';
import '../../maps/application/external_location_launcher.dart';
import '../../maps/application/location_destination_resolver.dart';
import '../../maps/data/location_resolution_repository.dart';
import '../../maps/domain/geographic_point.dart';
import '../../maps/domain/location_result.dart';

bool scheduleItemSupportsLocationOpening(ScheduleItem item) =>
    item is CalendarScheduleItem ||
    (item is TaskScheduleItem && item.provider == BusyProvider.nextcloud);

String scheduleItemLocationText(ScheduleItem item) => switch (item) {
  CalendarScheduleItem(:final location) => location ?? '',
  TaskScheduleItem(:final location) => location ?? '',
};

GeographicPoint? scheduleItemNativeLocationPoint(ScheduleItem item) =>
    switch (item) {
      CalendarScheduleItem(:final locationPoint) => locationPoint,
      TaskScheduleItem(:final locationPoint) => locationPoint,
    };

LocationItemIdentity scheduleItemLocationIdentity(ScheduleItem item) =>
    LocationItemIdentity(
      kind: item is CalendarScheduleItem
          ? LocationItemKind.event
          : LocationItemKind.task,
      accountId: item.accountId,
      sourceId: item.sourceId,
      itemId: item.id,
    );

ExternalLocationDestination? projectedScheduleItemLocationDestination(
  ScheduleItem item,
) {
  if (!scheduleItemSupportsLocationOpening(item)) return null;
  final location = scheduleItemLocationText(item);
  final link = completeHttpLocationUri(location);
  if (link != null) return ExternalLocationDestination.link(link);
  final point = scheduleItemNativeLocationPoint(item);
  if (point != null) return ExternalLocationDestination.coordinates(point);
  if (location.trim().isEmpty) return null;
  return ExternalLocationDestination.text(location);
}

Future<ExternalLocationDestination?> resolveSavedScheduleLocation({
  required ScheduleItem item,
  required LocationResolutionRepository repository,
}) async {
  if (!scheduleItemSupportsLocationOpening(item)) return null;
  try {
    return await LocationDestinationResolver(repository).resolveSaved(
      location: scheduleItemLocationText(item),
      nativePoint: scheduleItemNativeLocationPoint(item),
      identity: scheduleItemLocationIdentity(item),
    );
  } on Object {
    // Text and provider-native points remain usable if remembered-point
    // storage is temporarily unavailable.
    return projectedScheduleItemLocationDestination(item);
  }
}

String savedScheduleLocationDisplayText(
  ScheduleItem item,
  ExternalLocationDestination destination,
) {
  final location = scheduleItemLocationText(item);
  if (location.trim().isNotEmpty) return location;
  return switch (destination.kind) {
    ExternalLocationDestinationKind.coordinates =>
      destination.point!.directionsValue,
    ExternalLocationDestinationKind.text => destination.text!,
    ExternalLocationDestinationKind.link => destination.link!.toString(),
  };
}
