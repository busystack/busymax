import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/app_bootstrap.dart';
import '../../../core/auth/oauth_registration.dart';
import '../../../core/auth/registration_setup_controller.dart';
import '../../../providers/busy_provider.dart';
import '../../../l10n/registration_setup_content.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';

Future<RegistrationHandle?> showRegistrationSetup(
  BuildContext context,
  WidgetRef ref,
  BusyProvider provider,
) {
  final controller = RegistrationSetupController(
    ref.read(registrationStagingProvider),
    provider,
    platform: AuthenticationPlatform.desktop,
  );
  return showBusyMaxModalDialog<RegistrationHandle>(
    context,
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
      await showBusyMaxModalDialog<void>(
        context,
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
    return BusyMaxDialogShell(
      title: l10n.registrationSetupTitle(widget.provider.displayName),
      maxWidth: 560,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          key: const ValueKey('registration-authorize'),
          onPressed: setup.canConnect ? connect : null,
          child: Text(l10n.registrationConnect),
        ),
      ],
      children: [
        Text(
          google
              ? l10n.registrationGoogleIntroduction
              : l10n.registrationMicrosoftIntroduction,
        ),
        if (google) _googleForm(l10n) else _microsoftForm(l10n),
        if (error != null) ...[
          const SizedBox(height: BusyMaxSpacing.md),
          _error(error, const ValueKey('registration-error')),
        ],
        BusyMaxGroupedList(
          filled: true,
          children: [
            BusyMaxActionRow(
              key: const ValueKey('registration-guide'),
              title: l10n.registrationSetupInstructions,
              subtitleWidget: Text(l10n.registrationInstructionsDescription),
              trailing: const Icon(YaruIcons.go_next),
              onTap: showGuide,
            ),
          ],
        ),
      ],
    );
  }

  Widget _googleForm(AppLocalizations l10n) {
    final selected = setup.handle;
    return BusyMaxGroupedList(
      filled: true,
      children: [
        YaruListTile.square(
          title: Text(l10n.registrationDesktopConfiguration),
          subtitle: selected == null
              ? Text(l10n.registrationNoFileSelected)
              : SelectableText(
                  '${l10n.registrationGoogleProject}: ${selected.summary.projectId}',
                ),
          trailing: BusyMaxPushButton.standard(
            key: const ValueKey('registration-import'),
            autofocus: true,
            onPressed: setup.busy ? null : setup.validate,
            child: Text(
              selected == null
                  ? l10n.registrationChooseFile
                  : l10n.registrationReplaceFile,
            ),
          ),
        ),
        if (selected != null)
          YaruListTile.square(
            key: const ValueKey('registration-summary'),
            title: Text(l10n.registrationClientId),
            subtitle: SelectableText(selected.summary.clientId),
          ),
        if (setup.busy) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _microsoftForm(AppLocalizations l10n) => BusyMaxGroupedList(
    filled: true,
    children: [
      YaruListTile.square(
        title: TextField(
          key: const ValueKey('registration-client-id'),
          controller: client,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: busyMaxGroupedTextFieldDecoration(
            context,
            labelText: l10n.registrationClientId,
            errorText: setup.invalidClientId
                ? l10n.registrationInvalidId
                : null,
          ),
          onChanged: setup.updateClientId,
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final label = l10n.registrationAudienceLabel(setup.audience);
          final labelLayout = TextPainter(
            text: TextSpan(
              text: label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final valueWidth =
              (constraints.maxWidth * BusyMaxFormLayout.comboInlineMaxFraction)
                  .clamp(0.0, BusyMaxSizes.comboWidth) -
              BusyMaxSizes.iconSm -
              BusyMaxSpacing.sm;
          final showFullValue = labelLayout.width > valueWidth;
          labelLayout.dispose();
          return BusyMaxComboRow<MicrosoftAudience>(
            key: const ValueKey('registration-audience'),
            title: l10n.registrationAudience,
            // Preserve a readable selection when the shared trailing value elides.
            subtitle: showFullValue ? label : null,
            values: MicrosoftAudience.values,
            selected: setup.audience,
            labelFor: l10n.registrationAudienceLabel,
            tooltip: label,
            onSelected: (value) {
              if (value == setup.audience) return;
              tenant.clear();
              setup.updateAudience(value);
            },
          );
        },
      ),
      if (setup.audience == MicrosoftAudience.tenant)
        YaruListTile.square(
          title: TextField(
            key: const ValueKey('registration-tenant-id'),
            controller: tenant,
            textInputAction: TextInputAction.done,
            decoration: busyMaxGroupedTextFieldDecoration(
              context,
              labelText: l10n.registrationDirectoryId,
              errorText: setup.invalidTenantId
                  ? l10n.registrationInvalidId
                  : null,
            ),
            onChanged: setup.updateTenantId,
            onSubmitted: (_) {
              if (setup.canConnect) connect();
            },
          ),
        ),
    ],
  );

  Widget _error(String message, Key key) => Text(
    message,
    key: key,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.error,
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 640),
        child: BusyMaxDialogShell(
          key: const ValueKey('registration-instructions-dialog'),
          title: title,
          maxWidth: 560,
          header: Padding(
            padding: const EdgeInsets.all(BusyMaxSpacing.headerInset),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: BusyMaxSpacing.sm),
                YaruWindowControl(
                  key: const ValueKey('registration-instructions-close'),
                  type: YaruWindowControlType.close,
                  semanticLabel: l10n.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          children: _guide(l10n),
        ),
      ),
    );
  }

  Widget _error(String message, Key key) => Text(
    message,
    key: key,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.error,
    ),
  );

  List<Widget> _guide(AppLocalizations l10n) {
    final steps = l10n.registrationDesktopSteps(widget.provider);
    return [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) const SizedBox(height: BusyMaxSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            '${i + 1}. ${steps[i].heading}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(steps[i].body),
        if (steps[i].values case final values?)
          BusyMaxGroupedList(
            filled: true,
            children: [
              if (steps[i].copyAll)
                YaruListTile.square(
                  title: Text(steps[i].valuesLabel!),
                  trailing: BusyMaxPushButton.standard(
                    key: const ValueKey('registration-copy-all'),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: values)),
                    child: Text(l10n.registrationCopyAll),
                  ),
                ),
              for (final value in values.split('\n'))
                YaruListTile.square(
                  title: steps[i].copyAll
                      ? SelectableText(value)
                      : Text(steps[i].valuesLabel!),
                  subtitle: steps[i].copyAll ? null : SelectableText(value),
                  trailing: BusyMaxHeaderIconButton(
                    tooltip: l10n.registrationCopy,
                    icon: const Icon(YaruIcons.copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: value)),
                  ),
                ),
            ],
          ),
        if (linkError != null && failedStep == i) ...[
          const SizedBox(height: BusyMaxSpacing.sm),
          KeyedSubtree(
            key: linkErrorAnchor,
            child: _error(
              linkError!,
              const ValueKey('registration-link-error'),
            ),
          ),
        ],
        if (steps[i].link case final url?) ...[
          const SizedBox(height: BusyMaxSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BusyMaxPushButton.standard(
              onPressed: launching ? null : () => openLink(url, i),
              child: Text(steps[i].linkLabel!),
            ),
          ),
        ],
      ],
    ];
  }
}
