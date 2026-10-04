import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_bootstrap.dart';
import '../../core/auth/oauth_registration.dart';
import '../../core/auth/registration_setup_controller.dart';
import '../../providers/busy_provider.dart';
import '../../l10n/registration_setup_content.dart';
import '../../../l10n/generated/app_localizations.dart';

Future<RegistrationHandle?> showWindowsRegistrationSetup(
  BuildContext context,
  WidgetRef ref,
  BusyProvider provider,
) {
  final controller = RegistrationSetupController(
    ref.read(registrationStagingProvider),
    provider,
    platform: AuthenticationPlatform.desktop,
  );
  return showDialog<RegistrationHandle>(
    context: context,
    builder: (_) =>
        _RegistrationDialog(provider: provider, controller: controller),
  );
}

class _RegistrationDialog extends StatefulWidget {
  const _RegistrationDialog({required this.provider, required this.controller});
  final BusyProvider provider;
  final RegistrationSetupController controller;
  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  late final RegistrationSetupController setup = widget.controller;
  late final TextEditingController client = TextEditingController(
    text: setup.clientId,
  );
  late final TextEditingController tenant = TextEditingController(
    text: setup.tenantId,
  );
  bool instructionsOpen = false;

  @override
  void initState() {
    super.initState();
    setup.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> showGuide() async {
    if (instructionsOpen) return;
    instructionsOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _RegistrationInstructionsDialog(provider: widget.provider),
      );
    } finally {
      if (mounted) instructionsOpen = false;
    }
  }

  void connect() {
    final selected = setup.accept();
    if (selected != null) Navigator.pop(context, selected);
  }

  @override
  void dispose() {
    setup.removeListener(changed);
    setup.dispose();
    client.dispose();
    tenant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final google = widget.provider == BusyProvider.google;
    final error = l10n.registrationSetupError(setup);
    return ContentDialog(
      title: Text(l10n.registrationSetupTitle(widget.provider.displayName)),
      constraints: const BoxConstraints(maxWidth: 560),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('registration-authorize'),
          onPressed: setup.canConnect ? connect : null,
          child: Text(l10n.registrationConnect),
        ),
      ],
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              google
                  ? l10n.registrationGoogleIntroduction
                  : l10n.registrationMicrosoftIntroduction,
            ),
            const SizedBox(height: 12),
            Card(child: google ? _googleForm(l10n) : _microsoftForm(l10n)),
            if (error != null)
              _error(error, key: const ValueKey('registration-error')),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('registration-guide'),
              title: Text(l10n.registrationSetupInstructions),
              subtitle: Text(l10n.registrationInstructionsDescription),
              trailing: const Icon(FluentIcons.chevron_right),
              onPressed: showGuide,
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleForm(AppLocalizations l10n) {
    final selected = setup.handle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.registrationDesktopConfiguration,
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                  const SizedBox(height: 4),
                  if (selected == null)
                    Text(l10n.registrationNoFileSelected)
                  else
                    SelectableText(
                      '${l10n.registrationGoogleProject}: ${selected.summary.projectId}',
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Button(
              key: const ValueKey('registration-import'),
              autofocus: true,
              onPressed: setup.busy ? null : setup.validate,
              child: Text(
                selected == null
                    ? l10n.registrationChooseFile
                    : l10n.registrationReplaceFile,
              ),
            ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          InfoLabel(
            key: const ValueKey('registration-summary'),
            label: l10n.registrationClientId,
            child: SelectableText(selected.summary.clientId),
          ),
        ],
        if (setup.busy) ...[const SizedBox(height: 8), const ProgressBar()],
      ],
    );
  }

  Widget _microsoftForm(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InfoLabel(
        label: l10n.registrationClientId,
        child: TextBox(
          key: const ValueKey('registration-client-id'),
          controller: client,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: setup.updateClientId,
        ),
      ),
      if (setup.invalidClientId) _error(l10n.registrationInvalidId),
      const SizedBox(height: 12),
      InfoLabel(
        label: l10n.registrationAudience,
        child: ComboBox<MicrosoftAudience>(
          key: const ValueKey('registration-audience'),
          isExpanded: true,
          value: setup.audience,
          items: [
            for (final value in MicrosoftAudience.values)
              ComboBoxItem(
                value: value,
                child: Text(l10n.registrationAudienceLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value == null || value == setup.audience) return;
            tenant.clear();
            setup.updateAudience(value);
          },
        ),
      ),
      if (setup.audience == MicrosoftAudience.tenant) ...[
        const SizedBox(height: 12),
        InfoLabel(
          label: l10n.registrationDirectoryId,
          child: TextBox(
            key: const ValueKey('registration-tenant-id'),
            controller: tenant,
            textInputAction: TextInputAction.done,
            onChanged: setup.updateTenantId,
            onSubmitted: (_) {
              if (setup.canConnect) connect();
            },
          ),
        ),
        if (setup.invalidTenantId) _error(l10n.registrationInvalidId),
      ],
    ],
  );

  Widget _error(String message, {Key? key}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: InfoBar(
      key: key,
      severity: InfoBarSeverity.error,
      title: Text(message),
    ),
  );
}

class _RegistrationInstructionsDialog extends StatefulWidget {
  const _RegistrationInstructionsDialog({required this.provider});

  final BusyProvider provider;

  @override
  State<_RegistrationInstructionsDialog> createState() =>
      _RegistrationInstructionsDialogState();
}

class _RegistrationInstructionsDialogState
    extends State<_RegistrationInstructionsDialog> {
  bool launching = false;
  String? linkError;
  int? failedStep;
  int linkRevision = 0;
  final linkErrorAnchor = GlobalKey();

  Future<void> openLink(String url, int step) async {
    if (launching) return;
    final revision = ++linkRevision;
    setState(() {
      launching = true;
      linkError = null;
      failedStep = null;
    });
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!mounted || revision != linkRevision) return;
    setState(() {
      launching = false;
      if (!opened) {
        linkError = AppLocalizations.of(context).registrationLinkFailed;
        failedStep = step;
      }
    });
    if (!opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != linkRevision) return;
        final errorContext = linkErrorAnchor.currentContext;
        if (errorContext != null) {
          Scrollable.ensureVisible(errorContext, alignment: 0.5);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.provider == BusyProvider.google
        ? l10n.registrationGoogleSetupInstructions
        : l10n.registrationMicrosoftSetupInstructions;
    return ContentDialog(
      key: const ValueKey('registration-instructions-dialog'),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          Tooltip(
            message: l10n.close,
            child: IconButton(
              key: const ValueKey('registration-instructions-close'),
              autofocus: true,
              icon: const Icon(FluentIcons.chrome_close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _guide(l10n),
        ),
      ),
    );
  }

  Widget _error(String message, {Key? key}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: InfoBar(
      key: key,
      severity: InfoBarSeverity.error,
      title: Text(message),
    ),
  );

  List<Widget> _guide(AppLocalizations l10n) {
    final steps = l10n.registrationDesktopSteps(widget.provider);
    return [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            '${i + 1}. ${steps[i].heading}',
            style: FluentTheme.of(context).typography.subtitle,
          ),
        ),
        const SizedBox(height: 8),
        Text(steps[i].body),
        if (steps[i].values case final values?) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (steps[i].copyAll)
                  Row(
                    children: [
                      Expanded(child: Text(steps[i].valuesLabel!)),
                      Button(
                        key: const ValueKey('registration-copy-all'),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: values)),
                        child: Text(l10n.registrationCopyAll),
                      ),
                    ],
                  ),
                for (final value in values.split('\n'))
                  ListTile(
                    title: steps[i].copyAll
                        ? SelectableText(value)
                        : Text(steps[i].valuesLabel!),
                    subtitle: steps[i].copyAll ? null : SelectableText(value),
                    trailing: Tooltip(
                      message: l10n.registrationCopy,
                      child: IconButton(
                        icon: const Icon(FluentIcons.copy),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: value)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (linkError != null && failedStep == i)
          KeyedSubtree(
            key: linkErrorAnchor,
            child: _error(
              linkError!,
              key: const ValueKey('registration-link-error'),
            ),
          ),
        if (steps[i].link case final url?)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: HyperlinkButton(
              onPressed: launching ? null : () => openLink(url, i),
              child: Text(steps[i].linkLabel!),
            ),
          ),
      ],
    ];
  }
}
