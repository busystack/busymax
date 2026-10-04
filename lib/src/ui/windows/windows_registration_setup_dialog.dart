import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/busymax_shortcuts.dart';
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

enum _SetupPage { methods, configuration, instructions }

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
  _SetupPage page = _SetupPage.methods;
  DesktopConnectionMethod method = DesktopConnectionMethod.custom;
  bool returningFromInstructions = false;
  bool launching = false;
  String? linkError;
  int? failedStep;
  int linkRevision = 0;
  final linkErrorAnchor = GlobalKey();
  final backFocus = FocusNode(debugLabel: 'Registration Back');

  @override
  void initState() {
    super.initState();
    setup.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void navigate(_SetupPage target) {
    setState(() {
      returningFromInstructions =
          page == _SetupPage.instructions && target == _SetupPage.configuration;
      page = target;
      linkRevision++;
      launching = false;
      linkError = null;
      failedStep = null;
    });
    if (target == _SetupPage.instructions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && page == target) backFocus.requestFocus();
      });
    }
  }

  void chooseMethod(DesktopConnectionMethod value) {
    method = value;
    navigate(_SetupPage.configuration);
  }

  void showGuide() => navigate(_SetupPage.instructions);

  void back() {
    if (page == _SetupPage.instructions) {
      navigate(_SetupPage.configuration);
    } else if (page == _SetupPage.configuration) {
      navigate(_SetupPage.methods);
    }
  }

  bool get sharedAvailable => widget.provider == BusyProvider.google
      ? setup.staging.config.hasBusyMaxGoogleRegistration
      : setup.staging.config.hasBusyMaxMicrosoftRegistration;

  void connectWithBusyMax() {
    final selected = setup.connectWithBusyMax();
    if (selected != null) Navigator.pop(context, selected);
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
    backFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final google = widget.provider == BusyProvider.google;
    final error = l10n.registrationSetupError(setup);
    final title = page == _SetupPage.methods
        ? l10n.registrationSetupTitle(widget.provider.displayName)
        : page == _SetupPage.instructions
        ? l10n.registrationInstructionsTitle(widget.provider, method)
        : l10n.registrationConfigurationTitle(widget.provider, method);
    final dialog = ContentDialog(
      key: ValueKey('registration-${page.name}-dialog'),
      title: Row(
        children: [
          SizedBox(
            width: 40,
            child: page == _SetupPage.methods
                ? null
                : Tooltip(
                    message: l10n.registrationBack,
                    child: IconButton(
                      key: const ValueKey('registration-back'),
                      focusNode: backFocus,
                      autofocus: page == _SetupPage.instructions,
                      icon: const Icon(FluentIcons.back),
                      onPressed: back,
                    ),
                  ),
          ),
          Expanded(child: Text(title, textAlign: TextAlign.center)),
          Tooltip(
            message: l10n.close,
            child: IconButton(
              key: const ValueKey('registration-close'),
              icon: const Icon(FluentIcons.chrome_close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
      actions: page == _SetupPage.instructions
          ? null
          : [
              Button(
                autofocus: page == _SetupPage.methods && !sharedAvailable,
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              if (page == _SetupPage.configuration)
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
          children: page == _SetupPage.instructions
              ? _guide(l10n)
              : page == _SetupPage.methods
              ? _methods(l10n)
              : [
                  Text(
                    google
                        ? method == DesktopConnectionMethod.googleWorkspace
                              ? l10n.registrationWorkspaceIntroduction
                              : l10n.registrationGoogleIntroduction
                        : l10n.registrationMicrosoftIntroduction,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: google ? _googleForm(l10n) : _microsoftForm(l10n),
                  ),
                  if (error != null)
                    _error(error, key: const ValueKey('registration-error')),
                  const SizedBox(height: 12),
                  ListTile(
                    key: const ValueKey('registration-guide'),
                    autofocus: returningFromInstructions,
                    title: Text(l10n.registrationSetupInstructions),
                    subtitle: Text(l10n.registrationInstructionsDescription),
                    trailing: const Icon(FluentIcons.chevron_right),
                    onPressed: showGuide,
                  ),
                ],
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {BusyMaxShortcutActivators.back: back},
      child: dialog,
    );
  }

  List<Widget> _methods(AppLocalizations l10n) => [
    Text(l10n.registrationMethodsIntroduction),
    const SizedBox(height: 12),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton(
        key: const ValueKey('registration-busymax'),
        autofocus: true,
        onPressed: sharedAvailable ? connectWithBusyMax : null,
        child: Text(l10n.registrationConnectBusyMax),
      ),
    ),
    const SizedBox(height: 8),
    Text(l10n.registrationRecommended),
    if (!sharedAvailable)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          l10n.registrationSharedUnavailable,
          key: const ValueKey('registration-shared-unavailable'),
        ),
      ),
    const SizedBox(height: 20),
    InfoLabel(
      label: l10n.registrationOtherMethods,
      child: Card(
        child: Column(
          children: [
            if (widget.provider == BusyProvider.google)
              ListTile(
                key: const ValueKey('registration-workspace'),
                title: Text(l10n.registrationWorkspace),
                subtitle: Text(l10n.registrationWorkspaceDescription),
                trailing: const Icon(FluentIcons.chevron_right),
                onPressed: () =>
                    chooseMethod(DesktopConnectionMethod.googleWorkspace),
              ),
            ListTile(
              key: const ValueKey('registration-custom'),
              title: Text(
                widget.provider == BusyProvider.google
                    ? l10n.registrationGoogleCustom
                    : l10n.registrationMicrosoftCustom,
              ),
              subtitle: Text(l10n.registrationCustomDescription),
              trailing: const Icon(FluentIcons.chevron_right),
              onPressed: () => chooseMethod(DesktopConnectionMethod.custom),
            ),
          ],
        ),
      ),
    ),
  ];

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
              autofocus: !returningFromInstructions,
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
          autofocus: !returningFromInstructions,
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
    if (!mounted ||
        page != _SetupPage.instructions ||
        revision != linkRevision) {
      return;
    }
    setState(() {
      launching = false;
      if (!opened) {
        linkError = AppLocalizations.of(context).registrationLinkFailed;
        failedStep = step;
      }
    });
    if (!opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            page != _SetupPage.instructions ||
            revision != linkRevision) {
          return;
        }
        final errorContext = linkErrorAnchor.currentContext;
        if (errorContext != null) {
          Scrollable.ensureVisible(errorContext, alignment: 0.5);
        }
      });
    }
  }

  List<Widget> _guide(AppLocalizations l10n) {
    final steps = l10n.registrationDesktopSteps(
      widget.provider,
      method: method,
    );
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
        if (linkError != null && failedStep == i && steps[i].link != null)
          ListTile(
            title: SelectableText(steps[i].link!),
            trailing: Tooltip(
              message: l10n.registrationCopy,
              child: IconButton(
                icon: const Icon(FluentIcons.copy),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: steps[i].link!)),
              ),
            ),
          ),
      ],
    ];
  }
}
