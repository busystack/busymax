import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_bootstrap.dart';
import '../../features/feedback/data/feedback_api_client.dart';
import '../../features/feedback/data/feedback_submission.dart';
import '../../l10n/l10n.dart';

class AndroidFeedbackScreen extends ConsumerStatefulWidget {
  const AndroidFeedbackScreen({super.key});

  @override
  ConsumerState<AndroidFeedbackScreen> createState() =>
      _AndroidFeedbackScreenState();
}

class _AndroidFeedbackScreenState extends ConsumerState<AndroidFeedbackScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _email = TextEditingController();
  FeedbackCategory? _category;
  bool _technical = false;
  bool _submitting = false;
  bool _validate = false;
  String? _status;
  bool _statusError = false;
  String _submissionId = const Uuid().v4();

  bool get _dirty =>
      _category != null ||
      _subject.text.trim().isNotEmpty ||
      _message.text.trim().isNotEmpty ||
      _email.text.trim().isNotEmpty ||
      _technical;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_dirty && !_submitting,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || _submitting) return;
      final discard = await _confirmDiscard();
      if (!mounted || !discard) return;
      Navigator.pop(this.context);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sendFeedback),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(context.l10n.feedbackSubmit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          DropdownButtonFormField<FeedbackCategory>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: context.l10n.feedbackCategory,
              errorText:
                  _validate && !FeedbackValidation.categoryIsValid(_category)
                  ? context.l10n.feedbackCategoryRequired
                  : null,
            ),
            items: [
              for (final value in FeedbackCategory.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_categoryLabel(context, value)),
                ),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                    _category = value;
                    _changed();
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('android-feedback-subject'),
            controller: _subject,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: context.l10n.feedbackSubject,
              errorText:
                  _validate && !FeedbackValidation.subjectIsValid(_subject.text)
                  ? context.l10n.feedbackSubjectLengthError
                  : null,
            ),
            onChanged: (_) => setState(_changed),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('android-feedback-message'),
            controller: _message,
            enabled: !_submitting,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: context.l10n.feedbackDetailedMessage,
              alignLabelWithHint: true,
              errorText:
                  _validate && !FeedbackValidation.messageIsValid(_message.text)
                  ? context.l10n.feedbackMessageLengthError
                  : null,
            ),
            onChanged: (_) => setState(_changed),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.l10n.feedbackReplyEmail,
              errorText:
                  _validate &&
                      !FeedbackValidation.replyEmailIsValid(_email.text)
                  ? context.l10n.feedbackInvalidEmail
                  : null,
            ),
            onChanged: (_) => setState(_changed),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _technical,
            title: Text(context.l10n.feedbackIncludeTechnicalDetails),
            subtitle: Text(context.l10n.feedbackTechnicalDetailsDisclosure),
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                    _technical = value;
                    _changed();
                  }),
          ),
          if (_submitting) const LinearProgressIndicator(),
          if (_status case final value?)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  value,
                  style: TextStyle(
                    color: _statusError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  void _changed() {
    if (_statusError) _submissionId = const Uuid().v4();
    _status = null;
    _statusError = false;
  }

  Future<void> _submit() async {
    final category = _category;
    final valid =
        FeedbackValidation.categoryIsValid(category) &&
        FeedbackValidation.subjectIsValid(_subject.text) &&
        FeedbackValidation.messageIsValid(_message.text) &&
        FeedbackValidation.replyEmailIsValid(_email.text);
    setState(() => _validate = true);
    if (!valid || category == null) return;
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _submitting = true);
    try {
      final package = await PackageInfo.fromPlatform();
      final receipt = await ref
          .read(feedbackSubmissionServiceProvider)
          .submit(
            FeedbackSubmission(
              submissionId: _submissionId,
              appVersion: package.version.trim().isEmpty
                  ? 'unknown'
                  : package.version,
              buildNumber: package.buildNumber.trim().isEmpty
                  ? '0'
                  : package.buildNumber,
              category: category,
              subject: _subject.text,
              message: _message.text,
              replyEmail: _email.text,
              platform: Platform.operatingSystem,
              technicalDetails: _technical
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
      _email.clear();
      setState(() {
        _category = null;
        _technical = false;
        _validate = false;
        _status = context.l10n.feedbackSuccess(receipt.id);
        _statusError = false;
        _submissionId = const Uuid().v4();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = switch (error) {
          FeedbackConnectionFailure() => context.l10n.feedbackConnectionError,
          FeedbackTimeoutFailure() => context.l10n.feedbackTimeoutError,
          FeedbackRateLimitedFailure() => context.l10n.feedbackRateLimitedError,
          FeedbackRejectedFailure() => context.l10n.feedbackRejectedError,
          FeedbackServerFailure() => context.l10n.feedbackServerError,
          _ => context.l10n.feedbackServerError,
        };
        _statusError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;
}

String _categoryLabel(BuildContext context, FeedbackCategory category) =>
    switch (category) {
      FeedbackCategory.problem => context.l10n.feedbackCategoryProblem,
      FeedbackCategory.feature => context.l10n.feedbackCategoryFeature,
      FeedbackCategory.privacySecurity =>
        context.l10n.feedbackCategoryPrivacySecurity,
      FeedbackCategory.usability => context.l10n.feedbackCategoryUsability,
      FeedbackCategory.other => context.l10n.feedbackCategoryOther,
    };
