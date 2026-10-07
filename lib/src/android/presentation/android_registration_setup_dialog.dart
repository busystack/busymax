import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_bootstrap.dart';
import '../../core/auth/oauth_registration.dart';
import '../../core/auth/registration_setup_controller.dart';
import '../../providers/busy_provider.dart';
import '../../../l10n/generated/app_localizations.dart';

Future<RegistrationHandle?> showAndroidRegistrationSetup(
  BuildContext context,
  WidgetRef ref,
  BusyProvider provider,
) {
  final controller = RegistrationSetupController(
    ref.read(registrationStagingProvider),
    provider,
    platform: AuthenticationPlatform.android,
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
  AndroidRegistrationIdentity? identity;
  String? identityError;
  @override
  void initState() {
    super.initState();
    setup.addListener(changed);
    BusyMaxAndroidPlatform.instance.microsoftRegistrationIdentity().then(
      (value) {
        if (mounted) {
          if (value.retiringClientId case final id?) {
            setup.staging.rememberRetiringClient(id);
          }
          setState(() => identity = value);
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(
            () => identityError =
                'The installed package/signature does not match its native redirect. Install a correctly configured build.',
          );
        }
      },
    );
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      TextButton(
        key: const ValueKey('registration-authorize'),
        onPressed: setup.busy || setup.handle == null
            ? null
            : () => Navigator.pop(context, setup.accept()),
        child: Text(l10n.registrationAuthorize),
      ),
    ];
    final children = <Widget>[
      if (identity != null)
        SelectableText(
          l10n.registrationAndroidIdentity(
            identity!.packageName,
            identity!.signatureHash,
            identity!.redirectUri,
          ),
        ),
      if (identityError != null) Text(identityError!),
      Text(
        google
            ? l10n.registrationGoogleInstructions
            : l10n.registrationMicrosoftInstructions,
      ),
      TextButton(
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
      TextButton(
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
        TextField(
          key: const ValueKey('registration-client-id'),
          decoration: InputDecoration(labelText: l10n.registrationClientId),
          onChanged: (value) {
            setup.clientId = value;
            setup.clearSelection();
            changed();
          },
        ),
        DropdownButton<MicrosoftAudience>(
          value: setup.audience,
          items: [
            for (final value in MicrosoftAudience.values)
              DropdownMenuItem(
                value: value,
                child: Text(_audienceLabel(l10n, value)),
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
          TextField(
            decoration: InputDecoration(labelText: l10n.registrationTenantId),
            onChanged: (value) {
              setup.tenantId = value;
              setup.clearSelection();
              changed();
            },
          ),
      ],
      TextButton(
        key: const ValueKey('registration-validate'),
        onPressed: setup.busy || identity == null ? null : setup.validate,
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
    return AlertDialog(
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
