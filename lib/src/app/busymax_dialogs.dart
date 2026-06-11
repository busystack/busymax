import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';

Future<T?> showBusyMaxModalEditorDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  LinuxHeaderBarService? headerBarService,
  double maxWidth = BusyMaxSizes.compactDetailsWidth,
  double? maxHeight = 760,
}) async {
  final service = headerBarService;
  if (service != null) {
    unawaited(service.setModalBarrierVisible(true));
  }
  try {
    return await showDialog<T>(
      context: context,
      barrierColor: busyMaxModalBarrierColor(context),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(BusyMaxSpacing.lg),
          child: BusyMaxModalEditorSurface(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            child: builder(dialogContext),
          ),
        );
      },
    );
  } finally {
    if (service != null) {
      unawaited(service.setModalBarrierVisible(false));
    }
  }
}

Future<String?> showBusyMaxTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? initialValue,
  String? message,
  Color? barrierColor,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: barrierColor,
    builder: (context) => BusyMaxPromptDialog(
      title: title,
      label: label,
      actionLabel: actionLabel,
      initialValue: initialValue,
      message: message,
    ),
  );
}

Future<bool> showBusyMaxConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  Color? barrierColor,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: barrierColor,
    builder: (context) => BusyMaxConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return confirmed == true;
}
