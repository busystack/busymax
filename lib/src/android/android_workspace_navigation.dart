import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A transient deep link into the retained workspace, never another workspace
/// route. An identity is used so repeated notifications can be consumed once.
class AndroidWorkspaceRequest {
  AndroidWorkspaceRequest({
    required this.date,
    this.itemId,
    this.accountId,
    this.taskListId,
    this.summary = false,
  });
  final DateTime date;
  final String? itemId;
  final String? accountId;
  final String? taskListId;
  bool get task => taskListId != null;
  final bool summary;
}

final androidWorkspaceRequestProvider = StateProvider<AndroidWorkspaceRequest?>(
  (ref) => null,
);

final androidWorkspaceRouteObserver = RouteObserver<ModalRoute<dynamic>>();
