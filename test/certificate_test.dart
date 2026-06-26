import 'dart:io';

import 'package:git2dart/git2dart.dart';
import 'package:git2dart_binaries/git2dart_binaries.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GitCertificateSsh', () {
    test('fromFlag returns empty set for zero', () {
      expect(GitCertificateSsh.fromFlag(0), <GitCertificateSsh>{});
    });

    test('fromFlag returns matching flags for combined bitmask', () {
      expect(
        GitCertificateSsh.fromFlag(5),
        {GitCertificateSsh.md5, GitCertificateSsh.sha256},
      );
    });
  });

  group('Callbacks.certificateCheck', () {
    late Directory cloneDir;
    late Keypair keypair;

    setUp(() {
      cloneDir = Directory.systemTemp.createTempSync('clone');
      keypair = Keypair(
        username: 'git',
        pubKey: p.join('test', 'assets', 'keys', 'id_rsa.pub'),
        privateKey: p.join('test', 'assets', 'keys', 'id_rsa'),
        passPhrase: 'empty',
      );
    });

    tearDown(() {
      if ((Platform.isLinux || Platform.isMacOS) && cloneDir.existsSync()) {
        cloneDir.deleteSync(recursive: true);
      }
    });

    test(
      'accepts the connection and receives host key information',
      tags: 'remote_fetch',
      () {
        String? receivedHost;
        CertificateHostkey? receivedCert;

        final callbacks = Callbacks(
          credentials: keypair,
          certificateCheck: (cert, {required valid, required host}) {
            receivedHost = host;
            receivedCert = cert;
            return true;
          },
        );

        final repo = Repository.clone(
          url: 'ssh://git@github.com/libgit2/TestGitRepository',
          localPath: cloneDir.path,
          callbacks: callbacks,
        );

        expect(repo.isEmpty, false);
        expect(receivedHost, 'github.com');
        expect(receivedCert, isNotNull);
        expect(receivedCert!.available, isNotEmpty);
        expect(receivedCert!.toString(), contains('CertificateHostkey{'));
      },
    );

    test(
      'throws when certificateCheck rejects the connection',
      tags: 'remote_fetch',
      () {
        final callbacks = Callbacks(
          credentials: keypair,
          certificateCheck: (cert, {required valid, required host}) => false,
        );

        expect(
          () => Repository.clone(
            url: 'ssh://git@github.com/libgit2/TestGitRepository',
            localPath: cloneDir.path,
            callbacks: callbacks,
          ),
          throwsA(isA<LibGit2Error>()),
        );
      },
    );
  });
}
