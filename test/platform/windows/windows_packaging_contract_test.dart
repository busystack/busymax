import 'dart:io';

import 'package:busymax/src/platform/windows/windows_notification_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  final manifestSource = File(
    'tool/windows/AppxManifest.xml.template',
  ).readAsStringSync();
  final manifest = XmlDocument.parse(manifestSource);

  Iterable<XmlElement> elements(String localName) => manifest.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName);

  test('Store manifest stays x64-only and targets Windows 11 24H2', () {
    final identity = elements('Identity').single;
    final target = elements('TargetDeviceFamily').single;
    final application = elements('Application').single;

    expect(identity.getAttribute('ProcessorArchitecture'), 'x64');
    expect(target.getAttribute('Name'), 'Windows.Desktop');
    expect(target.getAttribute('MinVersion'), '10.0.26100.0');
    expect(application.getAttribute('Id'), 'BusyMax');
    expect(application.getAttribute('Executable'), 'busymax.exe');
    expect(
      application.getAttribute('EntryPoint'),
      'Windows.FullTrustApplication',
    );
  });

  test('Store manifest registers only required activation surfaces', () {
    final categories = elements(
      'Extension',
    ).map((element) => element.getAttribute('Category')).toSet();
    expect(categories, {
      'windows.fileTypeAssociation',
      'windows.protocol',
      'windows.startupTask',
      'windows.toastNotificationActivation',
      'windows.comServer',
    });
    expect(elements('FileType').map((element) => element.innerText).toList(), [
      '.ics',
    ]);
    expect(
      elements('Protocol').map((element) => element.getAttribute('Name')),
      ['webcal'],
    );

    final startup = elements('StartupTask').single;
    expect(startup.getAttribute('TaskId'), 'BusyMaxStartupTask');
    expect(startup.getAttribute('Enabled'), 'false');
    expect(
      startup.parentElement!.getAttribute(
        'Parameters',
        namespace:
            'http://schemas.microsoft.com/appx/manifest/uap/windows10/10',
      ),
      '--start-minimized',
    );

    final toastClsid = elements(
      'ToastNotificationActivation',
    ).single.getAttribute('ToastActivatorCLSID');
    final toast = elements('ToastNotificationActivation').single;
    expect(
      toast.name.namespaceUri,
      'http://schemas.microsoft.com/appx/manifest/desktop/windows10',
    );
    expect(
      toast.parentElement!.name.namespaceUri,
      'http://schemas.microsoft.com/appx/manifest/desktop/windows10',
    );
    final ignorableNamespaces = manifest.rootElement
        .getAttribute('IgnorableNamespaces')!
        .split(' ');
    expect(ignorableNamespaces, contains('desktop'));
    expect(ignorableNamespaces, isNot(contains('desktop4')));
    expect(manifestSource, isNot(contains('xmlns:desktop4=')));
    final comClsid = elements('Class').single.getAttribute('Id');
    expect(toastClsid, busyMaxToastActivatorClsid);
    expect(comClsid, toastClsid);
  });

  test('every manifest logo has a matching unqualified source asset', () {
    final references = <String>{
      elements('Logo').first.innerText,
      elements('Logo').last.innerText,
      elements('VisualElements').single.getAttribute('Square44x44Logo')!,
      elements('VisualElements').single.getAttribute('Square150x150Logo')!,
    };
    expect(references, {
      r'Assets\StoreLogo.png',
      r'Assets\FileAssociationLogo.png',
      r'Assets\Square44x44Logo.png',
      r'Assets\Square150x150Logo.png',
    });
    for (final reference in references) {
      final name = reference.split(r'\').last;
      expect(
        File('windows/runner/resources/msix/$name').existsSync(),
        isTrue,
        reason: reference,
      );
    }
  });

  test('Store manifest capability set remains minimal', () {
    final capabilities = elements('Capabilities').single.childElements
        .map((element) => element.getAttribute('Name'))
        .toSet();
    expect(capabilities, {'internetClient', 'runFullTrust'});
  });

  test('runner preserves native DPI and acknowledged per-user IPC', () {
    final executableManifest = File(
      'windows/runner/runner.exe.manifest',
    ).readAsStringSync();
    final runner = File(
      'windows/runner/single_instance.cpp',
    ).readAsStringSync();

    expect(executableManifest, contains('PerMonitorV2'));
    expect(
      executableManifest,
      contains('<requestedExecutionLevel level="asInvoker"'),
    );
    expect(runner, contains('CurrentUserSid()'));
    expect(runner, contains('PIPE_REJECT_REMOTE_CLIENTS'));
    expect(runner, contains('ConnectToActivationPipe'));
    expect(runner, contains('ERROR_FILE_NOT_FOUND'));
    expect(runner, contains('acknowledgment == 1'));
    expect(runner, contains('D:P(A;;GA;;;'));
  });
}
