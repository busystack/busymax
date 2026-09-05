import 'package:flutter/foundation.dart';

enum SidebarOrderSection { accounts, calendars, taskLists, subscriptions }

/// Local presentation order. Missing IDs remain saved so hiding a source or a
/// temporary sync snapshot cannot reset its position when it returns.
@immutable
class ScheduleSidebarOrder {
  factory ScheduleSidebarOrder({
    Iterable<String> accountIds = const [],
    Map<String, List<String>> calendarSourceIdsByAccount = const {},
    Map<String, List<String>> taskListIdsByAccount = const {},
    Iterable<String> subscriptionSourceIds = const [],
  }) => ScheduleSidebarOrder._(
    _ids(accountIds),
    _groups(calendarSourceIdsByAccount),
    _groups(taskListIdsByAccount),
    _ids(subscriptionSourceIds),
  );

  const ScheduleSidebarOrder.empty()
    : accountIds = const [],
      calendarSourceIdsByAccount = const {},
      taskListIdsByAccount = const {},
      subscriptionSourceIds = const [];

  const ScheduleSidebarOrder._(
    this.accountIds,
    this.calendarSourceIdsByAccount,
    this.taskListIdsByAccount,
    this.subscriptionSourceIds,
  );

  factory ScheduleSidebarOrder.fromJson(Object? value) {
    if (value is! Map) return const ScheduleSidebarOrder.empty();
    return ScheduleSidebarOrder(
      accountIds: _readIds(value['accountIds']),
      calendarSourceIdsByAccount: _readGroups(
        value['calendarSourceIdsByAccount'],
      ),
      taskListIdsByAccount: _readGroups(value['taskListIdsByAccount']),
      subscriptionSourceIds: _readIds(value['subscriptionSourceIds']),
    );
  }

  final List<String> accountIds;
  final Map<String, List<String>> calendarSourceIdsByAccount;
  final Map<String, List<String>> taskListIdsByAccount;
  final List<String> subscriptionSourceIds;

  Map<String, Object?> toJson() => {
    'accountIds': accountIds,
    'calendarSourceIdsByAccount': calendarSourceIdsByAccount,
    'taskListIdsByAccount': taskListIdsByAccount,
    'subscriptionSourceIds': subscriptionSourceIds,
  };

  List<String> sequence(SidebarOrderSection section, {String? accountId}) =>
      switch (section) {
        SidebarOrderSection.accounts => accountIds,
        SidebarOrderSection.calendars =>
          calendarSourceIdsByAccount[accountId] ?? const [],
        SidebarOrderSection.taskLists =>
          taskListIdsByAccount[accountId] ?? const [],
        SidebarOrderSection.subscriptions => subscriptionSourceIds,
      };

  List<T> apply<T>(
    SidebarOrderSection section,
    Iterable<T> items,
    String Function(T) id, {
    String? accountId,
  }) {
    final remaining = {for (final item in items) id(item): item};
    return [
      for (final savedId in sequence(section, accountId: accountId))
        if (remaining.containsKey(savedId)) remaining.remove(savedId) as T,
      ...remaining.values,
    ];
  }

  ScheduleSidebarOrder register(
    SidebarOrderSection section,
    Iterable<String> ids, {
    String? accountId,
  }) {
    final current = sequence(section, accountId: accountId);
    final next = {...current, ...ids}.toList();
    return listEquals(current, next) ? this : _with(section, next, accountId);
  }

  bool canMove(String id, int offset, List<String> siblings) {
    final index = siblings.indexOf(id);
    return offset.abs() == 1 &&
        index >= 0 &&
        index + offset >= 0 &&
        index + offset < siblings.length;
  }

  ScheduleSidebarOrder move(
    SidebarOrderSection section,
    String id,
    int offset,
    Iterable<String> presentIds, {
    String? accountId,
  }) {
    final registered = register(section, presentIds, accountId: accountId);
    final siblings = registered.apply(
      section,
      presentIds,
      (id) => id,
      accountId: accountId,
    );
    if (!canMove(id, offset, siblings)) return registered;
    final neighbor = siblings[siblings.indexOf(id) + offset];
    final next = [...registered.sequence(section, accountId: accountId)];
    final from = next.indexOf(id);
    final to = next.indexOf(neighbor);
    next[from] = neighbor;
    next[to] = id;
    return registered._with(section, next, accountId);
  }

  ScheduleSidebarOrder replaceId(
    SidebarOrderSection section,
    String oldId,
    String newId, {
    required String accountId,
  }) {
    final current = sequence(section, accountId: accountId);
    if (oldId == newId || !current.contains(oldId)) return this;
    return _with(section, [
      for (final id in current)
        if (id == oldId) newId else if (id != newId) id,
    ], accountId);
  }

  ScheduleSidebarOrder _with(
    SidebarOrderSection section,
    List<String> ids,
    String? accountId,
  ) {
    assert(
      accountId != null ||
          section == SidebarOrderSection.accounts ||
          section == SidebarOrderSection.subscriptions,
    );
    return ScheduleSidebarOrder(
      accountIds: section == SidebarOrderSection.accounts ? ids : accountIds,
      calendarSourceIdsByAccount: section == SidebarOrderSection.calendars
          ? {...calendarSourceIdsByAccount, accountId!: ids}
          : calendarSourceIdsByAccount,
      taskListIdsByAccount: section == SidebarOrderSection.taskLists
          ? {...taskListIdsByAccount, accountId!: ids}
          : taskListIdsByAccount,
      subscriptionSourceIds: section == SidebarOrderSection.subscriptions
          ? ids
          : subscriptionSourceIds,
    );
  }
}

List<String> _ids(Iterable<String> ids) => List.unmodifiable(ids.toSet());
Map<String, List<String>> _groups(Map<String, List<String>> groups) =>
    Map.unmodifiable(groups.map((key, value) => MapEntry(key, _ids(value))));
List<String> _readIds(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
Map<String, List<String>> _readGroups(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: _readIds(entry.value),
      }
    : const {};
