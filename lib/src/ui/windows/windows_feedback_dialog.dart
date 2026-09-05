import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/connectivity/network_connectivity_service.dart';
import '../../features/feedback/data/feedback_api_client.dart';
import '../../features/feedback/data/feedback_submission.dart';

Future<void> showWindowsFeedbackDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => WindowsFeedbackDialog(
      submissionService: ref.read(feedbackSubmissionServiceProvider),
    ),
  );
}

class WindowsFeedbackDialog extends StatefulWidget {
  const WindowsFeedbackDialog({required this.submissionService, super.key});

  final FeedbackSubmissionService submissionService;

  @override
  State<WindowsFeedbackDialog> createState() => _WindowsFeedbackDialogState();
}

class _WindowsFeedbackDialogState extends State<WindowsFeedbackDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _replyEmail = TextEditingController();
  FeedbackCategory? _category;
  var _includeTechnicalDetails = false;
  var _submitting = false;
  var _validationAttempted = false;
  String? _status;
  var _statusIsError = false;
  var _submissionId = const Uuid().v4();

  bool get _hasDraft =>
      _category != null ||
      _subject.text.trim().isNotEmpty ||
      _message.text.trim().isNotEmpty ||
      _replyEmail.text.trim().isNotEmpty ||
      _includeTechnicalDetails;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _replyEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validationMessage = _validationMessage(l10n);
    return ContentDialog(
      title: Text(l10n.reportAnIssue),
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoLabel(
              label: l10n.feedbackCategory,
              child: ComboBox<FeedbackCategory>(
                isExpanded: true,
                value: _category,
                placeholder: Text(l10n.feedbackSelectCategory),
                items: [
                  for (final category in FeedbackCategory.values)
                    ComboBoxItem(
                      value: category,
                      child: Text(_categoryLabel(l10n, category)),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _category = value),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.feedbackSubject,
              child: TextBox(
                controller: _subject,
                enabled: !_submitting,
                onChanged: (_) => setState(() => _status = null),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.feedbackDetailedMessage,
              child: TextBox(
                controller: _message,
                enabled: !_submitting,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() => _status = null),
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: l10n.feedbackReplyEmail,
              child: TextBox(
                controller: _replyEmail,
                enabled: !_submitting,
                onChanged: (_) => setState(() => _status = null),
              ),
            ),
            const SizedBox(height: 16),
            Checkbox(
              checked: _includeTechnicalDetails,
              onChanged: _submitting
                  ? null
                  : (value) => setState(
                      () => _includeTechnicalDetails = value ?? false,
                    ),
              content: Text(l10n.feedbackIncludeTechnicalDetails),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.feedbackTechnicalDetailsDisclosure,
              style: FluentTheme.of(context).typography.caption,
            ),
            if (validationMessage != null) ...[
              const SizedBox(height: 12),
              InfoBar(
                title: Text(validationMessage),
                severity: InfoBarSeverity.warning,
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: InfoBar(
                  title: Text(_status!),
                  severity: _statusIsError
                      ? InfoBarSeverity.error
                      : InfoBarSeverity.success,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _submitting ? null : _cancel,
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: ProgressRing())
              : Text(l10n.feedbackSubmit),
        ),
      ],
    );
  }

  String? _validationMessage(AppLocalizations l10n) {
    if (!_validationAttempted) return null;
    if (!FeedbackValidation.categoryIsValid(_category)) {
      return l10n.feedbackCategoryRequired;
    }
    if (!FeedbackValidation.subjectIsValid(_subject.text)) {
      return l10n.feedbackSubjectLengthError;
    }
    if (!FeedbackValidation.messageIsValid(_message.text)) {
      return l10n.feedbackMessageLengthError;
    }
    if (!FeedbackValidation.replyEmailIsValid(_replyEmail.text)) {
      return l10n.feedbackInvalidEmail;
    }
    return null;
  }

  Future<void> _cancel() async {
    if (!_hasDraft) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(l10n.discardChanges),
        content: Text(l10n.discardChangesConfirmation),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.discardChangesAction),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    setState(() {
      _validationAttempted = true;
      _status = null;
    });
    final category = _category;
    if (category == null ||
        _validationMessage(AppLocalizations.of(context)) != null) {
      return;
    }
    setState(() => _submitting = true);
    final locale = Localizations.localeOf(context).toLanguageTag();
    try {
      final package = await PackageInfo.fromPlatform();
      final receipt = await widget.submissionService.submit(
        FeedbackSubmission(
          submissionId: _submissionId,
          appVersion: package.version.isEmpty ? 'unknown' : package.version,
          buildNumber: package.buildNumber.isEmpty ? '0' : package.buildNumber,
          category: category,
          subject: _subject.text,
          message: _message.text,
          replyEmail: _replyEmail.text,
          platform: Platform.operatingSystem,
          technicalDetails: _includeTechnicalDetails
              ? FeedbackTechnicalDetails(
                  osVersion: Platform.operatingSystemVersion,
                  locale: locale,
                )
              : null,
        ),
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      _replyEmail.clear();
      setState(() {
        _category = null;
        _includeTechnicalDetails = false;
        _validationAttempted = false;
        _status = AppLocalizations.of(context).feedbackSuccess(receipt.id);
        _statusIsError = false;
        _submissionId = const Uuid().v4();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _failureMessage(AppLocalizations.of(context), error);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

String _categoryLabel(AppLocalizations l10n, FeedbackCategory category) =>
    switch (category) {
      FeedbackCategory.problem => l10n.feedbackCategoryProblem,
      FeedbackCategory.feature => l10n.feedbackCategoryFeature,
      FeedbackCategory.privacySecurity => l10n.feedbackCategoryPrivacySecurity,
      FeedbackCategory.usability => l10n.feedbackCategoryUsability,
      FeedbackCategory.other => l10n.feedbackCategoryOther,
    };

String _failureMessage(AppLocalizations l10n, Object error) => switch (error) {
  NetworkUnavailableException() ||
  FeedbackConnectionFailure() => l10n.feedbackConnectionError,
  FeedbackTimeoutFailure() => l10n.feedbackTimeoutError,
  FeedbackRateLimitedFailure() => l10n.feedbackRateLimitedError,
  FeedbackRejectedFailure() => l10n.feedbackRejectedError,
  _ => l10n.feedbackServerError,
};
