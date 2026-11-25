import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/updates/github_update.dart';
import 'package:planner/features/updates/update_controller.dart';

void main() {
  const tag = 'v1.3.0-build.250';
  const filename = 'acta-$tag-android-arm64.apk';
  final asset = <String, Object>{
    'name': filename,
    'state': 'uploaded',
    'size': 32000000,
    'digest': 'sha256:${'a' * 64}',
    'browser_download_url':
        'https://github.com/Call-me-ste/Acta/releases/download/$tag/$filename',
  };
  Map<String, Object> release([Map<String, Object>? onlyAsset]) => {
        'tag_name': tag,
        'draft': false,
        'prerelease': false,
        'assets': [onlyAsset ?? asset],
      };

  test('segnala una release ufficiale con build più alta', () {
    final update = GitHubUpdate.fromJson(release(), installedBuild: 54);
    expect(update?.build, 250);
    expect(update?.page.toString(), '$actaReleasePage$tag');
  });

  test('ignora release vecchie, bozze, prerelease e APK di altri canali', () {
    expect(GitHubUpdate.fromJson(release(), installedBuild: 250), isNull);
    expect(GitHubUpdate.fromJson(release(), installedBuild: 251), isNull);
    for (final entry in [
      {...release(), 'draft': true},
      {...release(), 'prerelease': true},
      {...release(), 'tag_name': '$tag\n'},
      release({...asset, 'name': 'app-qa-release.apk'}),
      release({...asset, 'digest': 'missing'}),
      release({...asset, 'size': -1}),
      release(
          {...asset, 'browser_download_url': 'https://example.org/$filename'}),
    ]) {
      expect(GitHubUpdate.fromJson(entry, installedBuild: 54), isNull);
    }
  });

  test('raggruppa i controlli e nasconde la scheda per la sessione', () async {
    var calls = 0;
    final controller = UpdateController(
      canCheck: () async => true,
      fetch: (installed) async {
        calls++;
        return GitHubUpdate.fromJson(release(), installedBuild: installed);
      },
    );
    addTearDown(controller.dispose);
    await Future.wait([controller.check(), controller.check()]);
    expect(calls, 1);
    expect(controller.visible?.build, 250);
    controller.dismiss();
    expect(controller.visible, isNull);
    expect(controller.available?.build, 250);
    await controller.check();
    expect(calls, 1);
    await controller.check(manual: true);
    expect(calls, 2);
    expect(controller.available?.build, 250);
    expect(controller.visible, isNull);
  });

  test('un errore di rete lascia il banner assente', () async {
    final controller = UpdateController(
      canCheck: () async => true,
      fetch: (_) async => throw StateError('offline'),
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.visible, isNull);
    expect(controller.status, UpdateCheckStatus.failed);
  });

  test('una release non pubblicata è distinta da un errore di rete', () async {
    final controller = UpdateController(
      canCheck: () async => true,
      fetch: (_) async => throw const GitHubReleaseNotFound(),
    );
    addTearDown(controller.dispose);
    await controller.check(manual: true);
    expect(controller.status, UpdateCheckStatus.noPublicRelease);
  });

  test('il controllo manuale rispetta il canale di installazione', () async {
    final controller = UpdateController(
      canCheck: () async => false,
      fetch: (_) async => fail('Non deve contattare GitHub'),
    );
    addTearDown(controller.dispose);
    await controller.check(manual: true);
    expect(controller.status, UpdateCheckStatus.unsupported);
  });
}
