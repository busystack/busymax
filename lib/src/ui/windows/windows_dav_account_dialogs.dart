import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers/busy_provider.dart';
import '../../dav/auth/caldav_credential_input.dart';
import '../../app/app_bootstrap.dart';

Future<void> showWindowsCalDavCollectionDialog(
  BuildContext context,
  String collectionId,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Consumer(
    builder: (context, ref, _) {
      final l10n = AppLocalizations.of(context);
      final collection = ref
          .watch(davCollectionsStreamProvider)
          .valueOrNull
          ?.where(
            (c) => c.id == collectionId && c.provider == BusyProvider.caldav,
          )
          .firstOrNull;
      return ContentDialog(
        title: Text(collection?.name ?? l10n.collectionSettings),
        content: collection == null
            ? Text(l10n.collectionsUnavailable)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!collection.capabilities.permissionsKnown)
                    Text(l10n.davPermissionsUnknown),
                  if (collection.readOnly) Text(l10n.readOnlySharedCollection),
                  if (collection.supportsEvents)
                    ToggleSwitch(
                      checked: collection.eventsSelected,
                      content: Text(l10n.calendarContent),
                      onChanged: (value) => ref
                          .read(davSettingsRepositoryProvider)
                          .setEventsSelected(collectionId, value),
                    ),
                  if (collection.supportsTasks)
                    ToggleSwitch(
                      checked: collection.tasksSelected,
                      content: Text(l10n.taskContent),
                      onChanged: (value) => ref
                          .read(davSettingsRepositoryProvider)
                          .setTasksSelected(collectionId, value),
                    ),
                ],
              ),
        actions: [
          Button(
            child: Text(l10n.close),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      );
    },
  ),
);

Future<CalDavCredentialInput?> showWindowsCalDavCredentialDialog(
  BuildContext context, {
  String? fixedServer,
  String? fixedUsername,
}) async {
  final server = TextEditingController(text: fixedServer);
  final username = TextEditingController(text: fixedUsername);
  final password = TextEditingController();
  var submitted = false;
  try {
    return await showDialog<CalDavCredentialInput>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(context);
          CalDavCredentialInput value() => CalDavCredentialInput(
            serverUrl: server.text.trim(),
            username: username.text,
            password: password.text,
          );
          void submit() {
            setState(() => submitted = true);
            if (value().isValid) Navigator.pop(dialogContext, value());
          }

          return ContentDialog(
            title: Text(l10n.registrationSetupTitle('CalDAV')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.caldavHttpsHelp),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.caldavServerUrl,
                    child: TextBox(
                      key: const Key('caldav-server-field'),
                      controller: server,
                      readOnly: fixedServer != null,
                      autofocus: fixedServer == null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.caldavUsername,
                    child: TextBox(
                      key: const Key('caldav-username-field'),
                      controller: username,
                      readOnly: fixedUsername != null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.caldavPassword,
                    child: TextBox(
                      key: const Key('caldav-password-field'),
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      onSubmitted: (_) => submit(),
                    ),
                  ),
                  if (submitted && !value().isValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InfoBar(
                        title: Text(
                          CalDavCredentialInput.isSafeServer(server.text)
                              ? l10n.requiredField
                              : l10n.caldavInvalidServerUrl,
                        ),
                        severity: InfoBarSeverity.warning,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(l10n.connectAccountAction),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    server.dispose();
    username.dispose();
    password.dispose();
  }
}

class WindowsAppleCredentialInput {
  const WindowsAppleCredentialInput({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

Future<WindowsAppleCredentialInput?> showWindowsAppleICloudDialog(
  BuildContext context,
) async {
  final email = TextEditingController();
  final password = TextEditingController();
  var validationAttempted = false;
  final result = await showDialog<WindowsAppleCredentialInput>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final invalid =
            validationAttempted &&
            (email.text.trim().isEmpty || password.text.trim().isEmpty);
        return ContentDialog(
          title: Text(l10n.connectAppleICloudTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: l10n.appleAccountEmail,
                child: TextBox(controller: email, autofocus: true),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.appleAppSpecificPassword,
                child: TextBox(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appleAppSpecificPasswordHelp,
                style: FluentTheme.of(context).typography.caption,
              ),
              if (invalid) ...[
                const SizedBox(height: 12),
                InfoBar(
                  title: Text(l10n.requiredField),
                  severity: InfoBarSeverity.warning,
                ),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (email.text.trim().isEmpty || password.text.trim().isEmpty) {
                  setState(() => validationAttempted = true);
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  WindowsAppleCredentialInput(
                    email: email.text.trim(),
                    password: password.text,
                  ),
                );
              },
              child: Text(l10n.connectAccountAction),
            ),
          ],
        );
      },
    ),
  );
  email.dispose();
  password.dispose();
  return result;
}

Future<String?> showWindowsNextcloudServerDialog(BuildContext context) async {
  final server = TextEditingController();
  var validationAttempted = false;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final title = l10n.registrationSetupTitle(
          BusyProvider.nextcloud.displayName,
        );
        return ContentDialog(
          title: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(child: Text(title, textAlign: TextAlign.center)),
              Tooltip(
                message: l10n.close,
                child: IconButton(
                  icon: const Icon(FluentIcons.chrome_close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxWidth: 560),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: l10n.nextcloudServerUrl,
                child: TextBox(controller: server, autofocus: true),
              ),
              const SizedBox(height: 8),
              Text(l10n.nextcloudServerUrlHelp),
              const SizedBox(height: 8),
              Text(l10n.nextcloudBrowserAuthorizationHelp),
              if (validationAttempted && server.text.trim().isEmpty) ...[
                const SizedBox(height: 12),
                InfoBar(
                  title: Text(l10n.requiredField),
                  severity: InfoBarSeverity.warning,
                ),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (server.text.trim().isEmpty) {
                  setState(() => validationAttempted = true);
                  return;
                }
                Navigator.pop(dialogContext, server.text.trim());
              },
              child: Text(l10n.connectAccountAction),
            ),
          ],
        );
      },
    ),
  );
  server.dispose();
  return result;
}
