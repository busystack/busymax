import 'dart:io';

/// Synthetic keys/certificates created in a disposable directory. Requires
/// OpenSSL; nothing is installed in platform, browser or user trust stores.
final class NextcloudTlsFixture {
  NextcloudTlsFixture._(this.directory);
  final Directory directory;
  String path(String file) => '${directory.path}/$file';
  Future<void> openssl(List<String> arguments) async {
    final result = await Process.run(
      'openssl',
      arguments,
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw StateError('OpenSSL fixture failed: ${result.stderr}');
    }
  }

  static Future<NextcloudTlsFixture> create() async {
    final fixture = NextcloudTlsFixture._(
      await Directory.systemTemp.createTemp('busymax-private-tls-'),
    );
    try {
      await fixture.openssl([
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-sha256',
        '-keyout',
        'ca.key',
        '-out',
        'ca.pem',
        '-days',
        '2',
        '-subj',
        '/CN=BusyMax synthetic CA',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
      ]);
      await fixture.openssl(['genrsa', '-out', 'server.key', '2048']);
      await fixture.openssl([
        'req',
        '-new',
        '-key',
        'server.key',
        '-out',
        'server.csr',
        '-subj',
        '/CN=localhost',
      ]);
      await File(fixture.path('server.ext'))
          .writeAsString('''basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1
''');
      for (final entry in {'leaf': '1', 'renewed': '2'}.entries) {
        await fixture.openssl([
          'x509',
          '-req',
          '-in',
          'server.csr',
          '-CA',
          'ca.pem',
          '-CAkey',
          'ca.key',
          '-set_serial',
          entry.value,
          '-days',
          '2',
          '-sha256',
          '-extfile',
          'server.ext',
          '-out',
          '${entry.key}.pem',
        ]);
      }
      for (final entry in {
        'self': '3',
        'self-renewed': '4',
        'expired': '5',
      }.entries) {
        await fixture.openssl([
          'x509',
          '-req',
          '-in',
          'server.csr',
          '-signkey',
          'server.key',
          '-set_serial',
          entry.value,
          '-days',
          entry.key == 'expired' ? '-1' : '2',
          '-sha256',
          '-extfile',
          'server.ext',
          '-out',
          '${entry.key}.pem',
        ]);
      }
      for (final entry in {
        'wrong': 'DNS:other.invalid',
        'wildcard': 'DNS:*.example.test',
        'dns-ip': 'DNS:127.0.0.1',
        'cn-only': null,
      }.entries) {
        final extensions = <String>[
          'basicConstraints=critical,CA:FALSE',
          'keyUsage=critical,digitalSignature',
          'extendedKeyUsage=serverAuth',
          if (entry.value != null) 'subjectAltName=${entry.value}',
        ];
        await File(fixture.path('${entry.key}.ext'))
            .writeAsString(extensions.join('\n'));
        await fixture.openssl([
          'x509',
          '-req',
          '-in',
          'server.csr',
          '-signkey',
          'server.key',
          '-set_serial',
          '6',
          '-days',
          '2',
          '-sha256',
          '-extfile',
          '${entry.key}.ext',
          '-out',
          '${entry.key}.pem',
        ]);
      }
      for (final name in ['wrong', 'cn-only']) {
        await fixture.openssl([
          'x509',
          '-req',
          '-in',
          'server.csr',
          '-CA',
          'ca.pem',
          '-CAkey',
          'ca.key',
          '-set_serial',
          '10',
          '-days',
          '2',
          '-sha256',
          '-extfile',
          '$name.ext',
          '-out',
          '$name-leaf.pem',
        ]);
      }
      await fixture.openssl([
        'x509',
        '-req',
        '-in',
        'server.csr',
        '-CA',
        'ca.pem',
        '-CAkey',
        'ca.key',
        '-set_serial',
        '11',
        '-days',
        '-1',
        '-sha256',
        '-extfile',
        'server.ext',
        '-out',
        'expired-leaf.pem',
      ]);
      await File(fixture.path('index.txt')).writeAsString('');
      await File(fixture.path('serial.txt')).writeAsString('12\n');
      await Directory(fixture.path('issued')).create();
      await File(fixture.path('future.cnf')).writeAsString('''
[ca]
default_ca=authority
[authority]
database=index.txt
serial=serial.txt
new_certs_dir=issued
default_md=sha256
policy=names
x509_extensions=server
[names]
commonName=supplied
[server]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost
''');
      String date(DateTime value) =>
          '${value.year}${value.month.toString().padLeft(2, '0')}'
          '${value.day.toString().padLeft(2, '0')}${value.hour.toString().padLeft(2, '0')}'
          '${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}Z';
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      await fixture.openssl([
        'ca',
        '-batch',
        '-config',
        'future.cnf',
        '-keyfile',
        'ca.key',
        '-cert',
        'ca.pem',
        '-in',
        'server.csr',
        '-startdate',
        date(future),
        '-enddate',
        date(future.add(const Duration(days: 1))),
        '-notext',
        '-out',
        'future-leaf.pem',
      ]);
      await fixture.openssl([
        'req',
        '-x509',
        '-newkey',
        'ec',
        '-pkeyopt',
        'ec_paramgen_curve:P-256',
        '-nodes',
        '-sha256',
        '-keyout',
        'ec.key',
        '-out',
        'ec.pem',
        '-days',
        '2',
        '-subj',
        '/CN=localhost',
        '-addext',
        'basicConstraints=critical,CA:FALSE',
        '-addext',
        'subjectAltName=DNS:localhost',
        '-addext',
        'keyUsage=digitalSignature',
      ]);
      await File(fixture.path('critical.ext')).writeAsString(
        '${await File(fixture.path('server.ext')).readAsString()}'
        '\n1.2.3.4.5.6=critical,DER:04:01:01\n',
      );
      await fixture.openssl([
        'x509',
        '-req',
        '-in',
        'server.csr',
        '-signkey',
        'server.key',
        '-days',
        '2',
        '-sha256',
        '-extfile',
        'critical.ext',
        '-out',
        'critical.pem',
      ]);
      await fixture.openssl([
        'req',
        '-x509',
        '-key',
        'ca.key',
        '-sha256',
        '-days',
        '2',
        '-subj',
        '/CN=BusyMax unsupported critical CA',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
        '-addext',
        '1.2.3.4.5.6=critical,DER:04:01:01',
        '-out',
        'critical-ca.pem',
      ]);
      await File(fixture.path('policy.ext')).writeAsString(
        '${await File(fixture.path('server.ext')).readAsString()}'
        '\ncertificatePolicies=critical,1.2.3.4\n',
      );
      await fixture.openssl([
        'x509',
        '-req',
        '-in',
        'server.csr',
        '-signkey',
        'server.key',
        '-days',
        '2',
        '-sha256',
        '-extfile',
        'policy.ext',
        '-out',
        'policy-leaf.pem',
      ]);
      await fixture.openssl([
        'req',
        '-x509',
        '-key',
        'ca.key',
        '-sha256',
        '-days',
        '2',
        '-subj',
        '/CN=BusyMax unsupported critical constraints CA',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
        '-addext',
        'nameConstraints=critical,permitted;DNS:.example.test',
        '-out',
        'constraints-ca.pem',
      ]);
      await fixture.openssl([
        'req',
        '-x509',
        '-key',
        'ca.key',
        '-sha256',
        '-days',
        '2',
        '-subj',
        '/CN=BusyMax unsuitable purpose CA',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
        '-addext',
        'extendedKeyUsage=critical,clientAuth',
        '-out',
        'purpose-ca.pem',
      ]);
      return fixture;
    } on Object {
      await fixture.dispose();
      rethrow;
    }
  }

  Future<HttpServer> serve(
    String certificate, {
    int port = 0,
    String key = 'server.key',
  }) => HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    port,
    SecurityContext()
      ..useCertificateChain(path('$certificate.pem'))
      ..usePrivateKey(path(key)),
  );
  Future<void> dispose() => directory.delete(recursive: true);
}
