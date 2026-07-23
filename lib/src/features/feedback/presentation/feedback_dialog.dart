import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../data/feedback_api_client.dart';
import '../data/feedback_submission.dart';

typedef FeedbackAppMetadataLoader = Future<FeedbackAppMetadata> Function();
typedef FeedbackSubmissionIdGenerator = String Function();
typedef FeedbackOsVersionProvider = String Function();

class FeedbackAppMetadata {
  const FeedbackAppMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

Future<void> showBusyMaxFeedbackDialog(
  BuildContext context, {
  required FeedbackSubmissionService submissionService,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalEditorDialog<void>(
    context,
    headerBarService: headerBarService,
    maxWidth: 680,
    maxHeight: 760,
    builder: (dialogContext) => BusyMaxFeedbackDialog(
      submissionService: submissionService,
      headerBarService: headerBarService,
      onCancel: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

class BusyMaxFeedbackDialog extends StatefulWidget {
  const BusyMaxFeedbackDialog({
    super.key,
    required this.submissionService,
    required this.onCancel,
    this.metadataLoader,
    this.submissionIdGenerator,
    this.osVersionProvider,
    this.headerBarService,
  });

  final FeedbackSubmissionService submissionService;
  final VoidCallback onCancel;
  final FeedbackAppMetadataLoader? metadataLoader;
  final FeedbackSubmissionIdGenerator? submissionIdGenerator;
  final FeedbackOsVersionProvider? osVersionProvider;
  final LinuxHeaderBarService? headerBarService;

  @override
  State<BusyMaxFeedbackDialog> createState() => _BusyMaxFeedbackDialogState();
}

class _BusyMaxFeedbackDialogState extends State<BusyMaxFeedbackDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _replyEmailController = TextEditingController();

  FeedbackCategory? _category;
  late String _submissionId;
  var _submissionAttempted = false;
  var _includeTechnicalDetails = false;
  var _validationAttempted = false;
  var _submitting = false;
  var _confirmingCancel = false;
  String? _statusMessage;
  var _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _submissionId = _newSubmissionId();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _replyEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categoryInvalid =
        _validationAttempted && !FeedbackValidation.categoryIsValid(_category);
    final subjectInvalid =
        _validationAttempted &&
        !FeedbackValidation.subjectIsValid(_subjectController.text);
    final messageInvalid =
        _validationAttempted &&
        !FeedbackValidation.messageIsValid(_messageController.text);
    final replyEmailInvalid =
        _validationAttempted &&
        !FeedbackValidation.replyEmailIsValid(_replyEmailController.text);

    return PopScope(
      canPop: !_submitting,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            unawaited(_cancel());
          },
        },
        child: Focus(
          autofocus: true,
          child: BusyMaxModalEditorScaffold(
            title: l10n.sendFeedback,
            cancelLabel: l10n.cancel,
            saveLabel: l10n.feedbackSubmit,
            onCancel: () => unawaited(_cancel()),
            cancelEnabled: !_submitting,
            onSave: _submitting ? null : _submit,
            saving: _submitting,
            children: [
              BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxComboRow<FeedbackCategory?>(
                    key: const Key('feedback-category'),
                    title: l10n.feedbackCategory,
                    errorText: categoryInvalid
                        ? l10n.feedbackCategoryRequired
                        : null,
                    values: const [null, ...FeedbackCategory.values],
                    selected: _category,
                    labelFor: (category) => category == null
                        ? l10n.feedbackSelectCategory
                        : _categoryLabel(context, category),
                    enabled: !_submitting,
                    onSelected: (value) {
                      setState(() {
                        _category = value;
                        _draftChanged();
                      });
                    },
                  ),
                  YaruListTile.square(
                    title: TextField(
                      key: const Key('feedback-subject'),
                      controller: _subjectController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.feedbackSubject,
                        errorText: subjectInvalid
                            ? l10n.feedbackSubjectLengthError
                            : null,
                      ),
                      onChanged: (_) => setState(_draftChanged),
                    ),
                  ),
                  YaruListTile.square(
                    title: TextField(
                      key: const Key('feedback-message'),
                      controller: _messageController,
                      enabled: !_submitting,
                      minLines: 4,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l10n.feedbackDetailedMessage,
                        alignLabelWithHint: true,
                        errorText: messageInvalid
                            ? l10n.feedbackMessageLengthError
                            : null,
                      ),
                      onChanged: (_) => setState(_draftChanged),
                    ),
                  ),
                  YaruListTile.square(
                    title: TextField(
                      key: const Key('feedback-reply-email'),
                      controller: _replyEmailController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.feedbackReplyEmail,
                        errorText: replyEmailInvalid
                            ? l10n.feedbackInvalidEmail
                            : null,
                      ),
                      onChanged: (_) => setState(_draftChanged),
                      onSubmitted: (_) {
                        if (!_submitting) {
                          _submit();
                        }
                      },
                    ),
                  ),
                ],
              ),
              BusyMaxGroupedList(
                filled: true,
                children: [
                  YaruCheckboxListTile(
                    key: const Key('feedback-technical-details'),
                    value: _includeTechnicalDetails,
                    onChanged: _submitting
                        ? null
                        : (value) {
                            setState(() {
                              _includeTechnicalDetails = value ?? false;
                              _draftChanged();
                            });
                          },
                    title: Text(l10n.feedbackIncludeTechnicalDetails),
                    subtitle: Text(l10n.feedbackTechnicalDetailsDisclosure),
                    shape: const RoundedRectangleBorder(),
                  ),
                ],
              ),
              if (_statusMessage case final status?) ...[
                const SizedBox(height: BusyMaxSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    key: const Key('feedback-status'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _statusIsError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: BusyMaxSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (_submitting || _confirmingCancel) {
      return;
    }
    final hasDraft =
        _category != null ||
        _subjectController.text.trim().isNotEmpty ||
        _messageController.text.trim().isNotEmpty ||
        _replyEmailController.text.trim().isNotEmpty ||
        _includeTechnicalDetails;
    if (!hasDraft) {
      widget.onCancel();
      return;
    }

    _confirmingCancel = true;
    try {
      final discard = await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discard,
        destructive: true,
        barrierColor: Colors.transparent,
        headerBarService: widget.headerBarService,
      );
      if (discard && mounted) {
        widget.onCancel();
      }
    } finally {
      _confirmingCancel = false;
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final category = _category;
    final subject = _subjectController.text;
    final message = _messageController.text;
    final replyEmail = _replyEmailController.text;
    final valid =
        FeedbackValidation.categoryIsValid(category) &&
        FeedbackValidation.subjectIsValid(subject) &&
        FeedbackValidation.messageIsValid(message) &&
        FeedbackValidation.replyEmailIsValid(replyEmail);

    setState(() {
      _validationAttempted = true;
      _statusMessage = null;
    });
    if (!valid || category == null) {
      return;
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final includeTechnicalDetails = _includeTechnicalDetails;
    setState(() => _submitting = true);

    try {
      final metadata = await (widget.metadataLoader ?? _loadMetadata)();
      final submission = FeedbackSubmission(
        submissionId: _submissionId,
        appVersion: _nonEmptyOr(metadata.version, 'unknown'),
        buildNumber: _nonEmptyOr(metadata.buildNumber, '0'),
        category: category,
        subject: subject,
        message: message,
        replyEmail: replyEmail,
        technicalDetails: includeTechnicalDetails
            ? FeedbackTechnicalDetails(
                osVersion:
                    (widget.osVersionProvider ?? _operatingSystemVersion)(),
                locale: locale,
              )
            : null,
      );
      _submissionAttempted = true;
      final receipt = await widget.submissionService.submit(submission);
      if (!mounted) {
        return;
      }
      _subjectController.clear();
      _messageController.clear();
      _replyEmailController.clear();
      setState(() {
        _category = null;
        _includeTechnicalDetails = false;
        _validationAttempted = false;
        _statusMessage = context.l10n.feedbackSuccess(receipt.id);
        _statusIsError = false;
        _submissionId = _newSubmissionId();
        _submissionAttempted = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = _failureMessage(context, error);
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _failureMessage(BuildContext context, Object error) {
    final l10n = context.l10n;
    return switch (error) {
      FeedbackConnectionFailure() => l10n.feedbackConnectionError,
      FeedbackTimeoutFailure() => l10n.feedbackTimeoutError,
      FeedbackRateLimitedFailure() => l10n.feedbackRateLimitedError,
      FeedbackRejectedFailure() => l10n.feedbackRejectedError,
      FeedbackServerFailure() => l10n.feedbackServerError,
      _ => l10n.feedbackServerError,
    };
  }

  String _newSubmissionId() {
    return (widget.submissionIdGenerator ?? _uuidV4)();
  }

  void _draftChanged() {
    if (_submissionAttempted) {
      _submissionId = _newSubmissionId();
      _submissionAttempted = false;
    }
    _statusMessage = null;
    _statusIsError = false;
  }
}

Future<FeedbackAppMetadata> _loadMetadata() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return FeedbackAppMetadata(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
}

String _uuidV4() => const Uuid().v4();

String _operatingSystemVersion() => Platform.operatingSystemVersion;

String _nonEmptyOr(String value, String fallback) {
  final normalized = value.trim();
  return normalized.isEmpty ? fallback : normalized;
}

String _categoryLabel(BuildContext context, FeedbackCategory category) {
  final l10n = context.l10n;
  return switch (category) {
    FeedbackCategory.problem => l10n.feedbackCategoryProblem,
    FeedbackCategory.feature => l10n.feedbackCategoryFeature,
    FeedbackCategory.privacySecurity => l10n.feedbackCategoryPrivacySecurity,
    FeedbackCategory.usability => l10n.feedbackCategoryUsability,
    FeedbackCategory.other => l10n.feedbackCategoryOther,
  };
}
