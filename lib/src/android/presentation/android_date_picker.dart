// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/week_preferences_scope.dart';

Future<DateTime?> showBusyMaxDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? errorFormatText,
  String? errorInvalidText,
  String? fieldHintText,
  String? fieldLabelText,
  TextInputType? keyboardType,
  ValueChanged<DatePickerEntryMode>? onDatePickerModeChange,
  Icon? switchToInputEntryModeIcon,
  Icon? switchToCalendarEntryModeIcon,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  TextDirection? textDirection,
  TransitionBuilder? builder,
  Offset? anchorPoint,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  currentDate: currentDate,
  initialEntryMode: initialEntryMode,
  selectableDayPredicate: selectableDayPredicate,
  helpText: helpText,
  cancelText: cancelText,
  confirmText: confirmText,
  initialDatePickerMode: initialDatePickerMode,
  errorFormatText: errorFormatText,
  errorInvalidText: errorInvalidText,
  fieldHintText: fieldHintText,
  fieldLabelText: fieldLabelText,
  keyboardType: keyboardType,
  onDatePickerModeChange: onDatePickerModeChange,
  switchToInputEntryModeIcon: switchToInputEntryModeIcon,
  switchToCalendarEntryModeIcon: switchToCalendarEntryModeIcon,
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  barrierLabel: barrierLabel,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
  textDirection: textDirection,
  anchorPoint: anchorPoint,
  builder: (pickerContext, child) {
    final actual = MaterialLocalizations.of(pickerContext);
    final firstWeekday = BusyMaxWeekPreferencesScope.firstWeekdayOf(
      pickerContext,
    );
    final localizedChild = Localizations.override(
      context: pickerContext,
      delegates: [_BusyMaxPickerLocalizationsDelegate(actual, firstWeekday)],
      child: child!,
    );
    return builder?.call(pickerContext, localizedChild) ?? localizedChild;
  },
);

class _BusyMaxPickerLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _BusyMaxPickerLocalizationsDelegate(this.actual, this.firstWeekday);

  final MaterialLocalizations actual;
  final int firstWeekday;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        _BusyMaxPickerMaterialLocalizations(actual, firstWeekday),
      );

  @override
  bool shouldReload(_BusyMaxPickerLocalizationsDelegate old) =>
      !identical(old.actual, actual) || old.firstWeekday != firstWeekday;
}

class _BusyMaxPickerMaterialLocalizations implements MaterialLocalizations {
  const _BusyMaxPickerMaterialLocalizations(this._delegate, this._firstWeekday);

  final MaterialLocalizations _delegate;
  final int _firstWeekday;

  @override
  String get openAppDrawerTooltip => _delegate.openAppDrawerTooltip;
  @override
  String get backButtonTooltip => _delegate.backButtonTooltip;
  @override
  String get clearButtonTooltip => _delegate.clearButtonTooltip;
  @override
  String get closeButtonTooltip => _delegate.closeButtonTooltip;
  @override
  String get deleteButtonTooltip => _delegate.deleteButtonTooltip;
  @override
  String get moreButtonTooltip => _delegate.moreButtonTooltip;
  @override
  String get nextMonthTooltip => _delegate.nextMonthTooltip;
  @override
  String get previousMonthTooltip => _delegate.previousMonthTooltip;
  @override
  String get firstPageTooltip => _delegate.firstPageTooltip;
  @override
  String get lastPageTooltip => _delegate.lastPageTooltip;
  @override
  String get nextPageTooltip => _delegate.nextPageTooltip;
  @override
  String get previousPageTooltip => _delegate.previousPageTooltip;
  @override
  String get showMenuTooltip => _delegate.showMenuTooltip;
  @override
  String aboutListTileTitle(String applicationName) =>
      _delegate.aboutListTileTitle(applicationName);
  @override
  String get licensesPageTitle => _delegate.licensesPageTitle;
  @override
  String licensesPackageDetailText(int licenseCount) =>
      _delegate.licensesPackageDetailText(licenseCount);
  @override
  String pageRowsInfoTitle(
    int firstRow,
    int lastRow,
    int rowCount,
    bool rowCountIsApproximate,
  ) => _delegate.pageRowsInfoTitle(
    firstRow,
    lastRow,
    rowCount,
    rowCountIsApproximate,
  );
  @override
  String get rowsPerPageTitle => _delegate.rowsPerPageTitle;
  @override
  String tabLabel({required int tabIndex, required int tabCount}) =>
      _delegate.tabLabel(tabIndex: tabIndex, tabCount: tabCount);
  @override
  String selectedRowCountTitle(int selectedRowCount) =>
      _delegate.selectedRowCountTitle(selectedRowCount);
  @override
  String get cancelButtonLabel => _delegate.cancelButtonLabel;
  @override
  String get closeButtonLabel => _delegate.closeButtonLabel;
  @override
  String get continueButtonLabel => _delegate.continueButtonLabel;
  @override
  String get copyButtonLabel => _delegate.copyButtonLabel;
  @override
  String get cutButtonLabel => _delegate.cutButtonLabel;
  @override
  String get scanTextButtonLabel => _delegate.scanTextButtonLabel;
  @override
  String get okButtonLabel => _delegate.okButtonLabel;
  @override
  String get pasteButtonLabel => _delegate.pasteButtonLabel;
  @override
  String get selectAllButtonLabel => _delegate.selectAllButtonLabel;
  @override
  String get lookUpButtonLabel => _delegate.lookUpButtonLabel;
  @override
  String get searchWebButtonLabel => _delegate.searchWebButtonLabel;
  @override
  String get shareButtonLabel => _delegate.shareButtonLabel;
  @override
  String get viewLicensesButtonLabel => _delegate.viewLicensesButtonLabel;
  @override
  String get anteMeridiemAbbreviation => _delegate.anteMeridiemAbbreviation;
  @override
  String get postMeridiemAbbreviation => _delegate.postMeridiemAbbreviation;
  @override
  String get timePickerHourModeAnnouncement =>
      _delegate.timePickerHourModeAnnouncement;
  @override
  String get timePickerMinuteModeAnnouncement =>
      _delegate.timePickerMinuteModeAnnouncement;
  @override
  String get modalBarrierDismissLabel => _delegate.modalBarrierDismissLabel;
  @override
  String get menuDismissLabel => _delegate.menuDismissLabel;
  @override
  String get drawerLabel => _delegate.drawerLabel;
  @override
  String get popupMenuLabel => _delegate.popupMenuLabel;
  @override
  String get menuBarMenuLabel => _delegate.menuBarMenuLabel;
  @override
  String get dialogLabel => _delegate.dialogLabel;
  @override
  String get alertDialogLabel => _delegate.alertDialogLabel;
  @override
  String get searchFieldLabel => _delegate.searchFieldLabel;
  @override
  String get currentDateLabel => _delegate.currentDateLabel;
  @override
  String get selectedDateLabel => _delegate.selectedDateLabel;
  @override
  String get scrimLabel => _delegate.scrimLabel;
  @override
  String get bottomSheetLabel => _delegate.bottomSheetLabel;
  @override
  String scrimOnTapHint(String modalRouteContentName) =>
      _delegate.scrimOnTapHint(modalRouteContentName);
  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      _delegate.timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat);
  @override
  ScriptCategory get scriptCategory => _delegate.scriptCategory;
  @override
  String formatDecimal(int number) => _delegate.formatDecimal(number);
  @override
  String formatHour(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => _delegate.formatHour(
    timeOfDay,
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
  @override
  String formatMinute(TimeOfDay timeOfDay) => _delegate.formatMinute(timeOfDay);
  @override
  String formatTimeOfDay(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => _delegate.formatTimeOfDay(
    timeOfDay,
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
  @override
  String formatYear(DateTime date) => _delegate.formatYear(date);
  @override
  String formatCompactDate(DateTime date) => _delegate.formatCompactDate(date);
  @override
  String formatShortDate(DateTime date) => _delegate.formatShortDate(date);
  @override
  String formatMediumDate(DateTime date) => _delegate.formatMediumDate(date);
  @override
  String formatFullDate(DateTime date) => _delegate.formatFullDate(date);
  @override
  String formatMonthYear(DateTime date) => _delegate.formatMonthYear(date);
  @override
  String formatShortMonthDay(DateTime date) =>
      _delegate.formatShortMonthDay(date);
  @override
  DateTime? parseCompactDate(String? inputString) =>
      _delegate.parseCompactDate(inputString);
  @override
  List<String> get narrowWeekdays => _delegate.narrowWeekdays;
  @override
  int get firstDayOfWeekIndex =>
      _firstWeekday == DateTime.sunday ? 0 : _firstWeekday;
  @override
  String get dateSeparator => _delegate.dateSeparator;
  @override
  String get dateHelpText => _delegate.dateHelpText;
  @override
  String get selectYearSemanticsLabel => _delegate.selectYearSemanticsLabel;
  @override
  String get unspecifiedDate => _delegate.unspecifiedDate;
  @override
  String get unspecifiedDateRange => _delegate.unspecifiedDateRange;
  @override
  String get dateInputLabel => _delegate.dateInputLabel;
  @override
  String get dateRangeStartLabel => _delegate.dateRangeStartLabel;
  @override
  String get dateRangeEndLabel => _delegate.dateRangeEndLabel;
  @override
  String dateRangeStartDateSemanticLabel(String formattedDate) =>
      _delegate.dateRangeStartDateSemanticLabel(formattedDate);
  @override
  String dateRangeEndDateSemanticLabel(String formattedDate) =>
      _delegate.dateRangeEndDateSemanticLabel(formattedDate);
  @override
  String get invalidDateFormatLabel => _delegate.invalidDateFormatLabel;
  @override
  String get invalidDateRangeLabel => _delegate.invalidDateRangeLabel;
  @override
  String get dateOutOfRangeLabel => _delegate.dateOutOfRangeLabel;
  @override
  String get saveButtonLabel => _delegate.saveButtonLabel;
  @override
  String get datePickerHelpText => _delegate.datePickerHelpText;
  @override
  String get dateRangePickerHelpText => _delegate.dateRangePickerHelpText;
  @override
  String get calendarModeButtonLabel => _delegate.calendarModeButtonLabel;
  @override
  String get inputDateModeButtonLabel => _delegate.inputDateModeButtonLabel;
  @override
  String get timePickerDialHelpText => _delegate.timePickerDialHelpText;
  @override
  String get timePickerInputHelpText => _delegate.timePickerInputHelpText;
  @override
  String get timePickerHourLabel => _delegate.timePickerHourLabel;
  @override
  String get timePickerMinuteLabel => _delegate.timePickerMinuteLabel;
  @override
  String get invalidTimeLabel => _delegate.invalidTimeLabel;
  @override
  String get dialModeButtonLabel => _delegate.dialModeButtonLabel;
  @override
  String get inputTimeModeButtonLabel => _delegate.inputTimeModeButtonLabel;
  @override
  String get signedInLabel => _delegate.signedInLabel;
  @override
  String get hideAccountsLabel => _delegate.hideAccountsLabel;
  @override
  String get showAccountsLabel => _delegate.showAccountsLabel;
  @override
  String get reorderItemToStart => _delegate.reorderItemToStart;
  @override
  String get reorderItemToEnd => _delegate.reorderItemToEnd;
  @override
  String get reorderItemUp => _delegate.reorderItemUp;
  @override
  String get reorderItemDown => _delegate.reorderItemDown;
  @override
  String get reorderItemLeft => _delegate.reorderItemLeft;
  @override
  String get reorderItemRight => _delegate.reorderItemRight;
  @override
  String get expandedIconTapHint => _delegate.expandedIconTapHint;
  @override
  String get collapsedIconTapHint => _delegate.collapsedIconTapHint;
  @override
  String get expansionTileExpandedHint => _delegate.expansionTileExpandedHint;
  @override
  String get expansionTileCollapsedHint => _delegate.expansionTileCollapsedHint;
  @override
  String get expansionTileExpandedTapHint =>
      _delegate.expansionTileExpandedTapHint;
  @override
  String get expansionTileCollapsedTapHint =>
      _delegate.expansionTileCollapsedTapHint;
  @override
  String get expandedHint => _delegate.expandedHint;
  @override
  String get collapsedHint => _delegate.collapsedHint;
  @override
  String remainingTextFieldCharacterCount(int remaining) =>
      _delegate.remainingTextFieldCharacterCount(remaining);
  @override
  String get refreshIndicatorSemanticLabel =>
      _delegate.refreshIndicatorSemanticLabel;
  @override
  String get keyboardKeyAlt => _delegate.keyboardKeyAlt;
  @override
  String get keyboardKeyAltGraph => _delegate.keyboardKeyAltGraph;
  @override
  String get keyboardKeyBackspace => _delegate.keyboardKeyBackspace;
  @override
  String get keyboardKeyCapsLock => _delegate.keyboardKeyCapsLock;
  @override
  String get keyboardKeyChannelDown => _delegate.keyboardKeyChannelDown;
  @override
  String get keyboardKeyChannelUp => _delegate.keyboardKeyChannelUp;
  @override
  String get keyboardKeyControl => _delegate.keyboardKeyControl;
  @override
  String get keyboardKeyDelete => _delegate.keyboardKeyDelete;
  @override
  String get keyboardKeyEject => _delegate.keyboardKeyEject;
  @override
  String get keyboardKeyEnd => _delegate.keyboardKeyEnd;
  @override
  String get keyboardKeyEscape => _delegate.keyboardKeyEscape;
  @override
  String get keyboardKeyFn => _delegate.keyboardKeyFn;
  @override
  String get keyboardKeyHome => _delegate.keyboardKeyHome;
  @override
  String get keyboardKeyInsert => _delegate.keyboardKeyInsert;
  @override
  String get keyboardKeyMeta => _delegate.keyboardKeyMeta;
  @override
  String get keyboardKeyMetaMacOs => _delegate.keyboardKeyMetaMacOs;
  @override
  String get keyboardKeyMetaWindows => _delegate.keyboardKeyMetaWindows;
  @override
  String get keyboardKeyNumLock => _delegate.keyboardKeyNumLock;
  @override
  String get keyboardKeyNumpad1 => _delegate.keyboardKeyNumpad1;
  @override
  String get keyboardKeyNumpad2 => _delegate.keyboardKeyNumpad2;
  @override
  String get keyboardKeyNumpad3 => _delegate.keyboardKeyNumpad3;
  @override
  String get keyboardKeyNumpad4 => _delegate.keyboardKeyNumpad4;
  @override
  String get keyboardKeyNumpad5 => _delegate.keyboardKeyNumpad5;
  @override
  String get keyboardKeyNumpad6 => _delegate.keyboardKeyNumpad6;
  @override
  String get keyboardKeyNumpad7 => _delegate.keyboardKeyNumpad7;
  @override
  String get keyboardKeyNumpad8 => _delegate.keyboardKeyNumpad8;
  @override
  String get keyboardKeyNumpad9 => _delegate.keyboardKeyNumpad9;
  @override
  String get keyboardKeyNumpad0 => _delegate.keyboardKeyNumpad0;
  @override
  String get keyboardKeyNumpadAdd => _delegate.keyboardKeyNumpadAdd;
  @override
  String get keyboardKeyNumpadComma => _delegate.keyboardKeyNumpadComma;
  @override
  String get keyboardKeyNumpadDecimal => _delegate.keyboardKeyNumpadDecimal;
  @override
  String get keyboardKeyNumpadDivide => _delegate.keyboardKeyNumpadDivide;
  @override
  String get keyboardKeyNumpadEnter => _delegate.keyboardKeyNumpadEnter;
  @override
  String get keyboardKeyNumpadEqual => _delegate.keyboardKeyNumpadEqual;
  @override
  String get keyboardKeyNumpadMultiply => _delegate.keyboardKeyNumpadMultiply;
  @override
  String get keyboardKeyNumpadParenLeft => _delegate.keyboardKeyNumpadParenLeft;
  @override
  String get keyboardKeyNumpadParenRight =>
      _delegate.keyboardKeyNumpadParenRight;
  @override
  String get keyboardKeyNumpadSubtract => _delegate.keyboardKeyNumpadSubtract;
  @override
  String get keyboardKeyPageDown => _delegate.keyboardKeyPageDown;
  @override
  String get keyboardKeyPageUp => _delegate.keyboardKeyPageUp;
  @override
  String get keyboardKeyPower => _delegate.keyboardKeyPower;
  @override
  String get keyboardKeyPowerOff => _delegate.keyboardKeyPowerOff;
  @override
  String get keyboardKeyPrintScreen => _delegate.keyboardKeyPrintScreen;
  @override
  String get keyboardKeyScrollLock => _delegate.keyboardKeyScrollLock;
  @override
  String get keyboardKeySelect => _delegate.keyboardKeySelect;
  @override
  String get keyboardKeyShift => _delegate.keyboardKeyShift;
  @override
  String get keyboardKeySpace => _delegate.keyboardKeySpace;
}
