import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_bootstrap.dart';
import '../../core/auth/oauth_registration.dart';
import '../../core/auth/registration_setup_controller.dart';
import '../../providers/busy_provider.dart';
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
  String? guide;
  @override
  void initState() {
    super.initState();
    setup.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    setup.removeListener(changed);
    setup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final google = widget.provider == BusyProvider.google;
    final actions = <Widget>[
      Button(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      FilledButton(
        key: const ValueKey('registration-authorize'),
        onPressed: setup.busy || setup.handle == null
            ? null
            : () => Navigator.pop(context, setup.accept()),
        child: Text(l10n.registrationAuthorize),
      ),
    ];
    final children = <Widget>[
      Text(
        google
            ? l10n.registrationGoogleInstructions
            : l10n.registrationMicrosoftInstructions,
      ),
      Button(
        onPressed: () async {
          final text = await rootBundle.loadString(
            google ? 'docs/google_setup.md' : 'docs/microsoft_setup.md',
          );
          if (mounted) {
            setState(() => guide = registrationOnboardingGuide(text));
          }
        },
        child: Text(l10n.registrationSetupGuide),
      ),
      if (guide != null)
        SizedBox(
          height: 220,
          child: SingleChildScrollView(child: Text(guide!)),
        ),
      HyperlinkButton(
        onPressed: () => launchUrl(
          Uri.parse(
            google
                ? 'https://developers.google.com/identity/protocols/oauth2/native-app'
                : 'https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app',
          ),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(l10n.registrationOfficialDocumentation),
      ),
      if (!google) ...[
        TextBox(
          key: const ValueKey('registration-client-id'),
          placeholder: l10n.registrationClientId,
          onChanged: (value) {
            setup.clientId = value;
            setup.clearSelection();
            changed();
          },
        ),
        ComboBox<MicrosoftAudience>(
          isExpanded: true,
          value: setup.audience,
          items: [
            for (final value in MicrosoftAudience.values)
              ComboBoxItem(
                value: value,
                child: Text(
                  _audienceLabel(l10n, value),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setup.audience = value;
              setup.clearSelection();
              changed();
            }
          },
        ),
        if (setup.audience == MicrosoftAudience.tenant)
          TextBox(
            placeholder: l10n.registrationTenantId,
            onChanged: (value) {
              setup.tenantId = value;
              setup.clearSelection();
              changed();
            },
          ),
      ],
      Button(
        key: const ValueKey('registration-validate'),
        onPressed: setup.busy ? null : setup.validate,
        child: Text(
          google ? l10n.registrationImportGoogle : l10n.registrationValidate,
        ),
      ),
      if (setup.handle case final handle?)
        Text(l10n.registrationSummary(handle.summary.clientId)),
      if (setup.handle?.summary.projectId case final project?)
        Text('${l10n.registrationGoogleProject}: $project'),
      if (setup.handle?.summary.authority case final authority?)
        Text('${l10n.registrationAudience}: $authority'),
      if (setup.error != null) Text(setup.error!),
    ];
    return ContentDialog(
      title: Text(l10n.registrationSetupTitle(widget.provider.displayName)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
      actions: actions,
    );
  }
}

String _audienceLabel(AppLocalizations l10n, MicrosoftAudience value) =>
    switch (value) {
      MicrosoftAudience.personalAndOrganizations =>
        l10n.registrationBothAudience,
      MicrosoftAudience.organizations => l10n.registrationOrganizationAudience,
      MicrosoftAudience.personal => l10n.registrationPersonalAudience,
      MicrosoftAudience.tenant => l10n.registrationTenantAudience,
    };
