import 'package:yaru/yaru.dart';

import 'busymax_design.dart';

abstract final class BusyMaxLayoutRules {
  static const double sidebarBreakpoint =
      kYaruMasterDetailBreakpoint + BusyMaxSizes.sidebarWidth / 4;
  static const double detailsBreakpoint = kYaruMasterDetailBreakpoint * 2;
  static const double taskPageMinWidth =
      kYaruMasterDetailBreakpoint - BusyMaxSizes.sidebarWidth / 2;

  static bool showSidebar(double width) => width >= sidebarBreakpoint;

  static bool showPersistentDetails(double width) => width >= detailsBreakpoint;
}
