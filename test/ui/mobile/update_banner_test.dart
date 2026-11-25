import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/database/database_service.dart';
import 'package:planner/features/backup/backup_controller.dart';
import 'package:planner/features/backup/backup_service.dart';
import 'package:planner/features/notes/note_attachment_store.dart';
import 'package:planner/features/settings/app_settings_controller.dart';
import 'package:planner/features/updates/github_update.dart';
import 'package:planner/features/updates/update_controller.dart';
import 'package:planner/ui/mobile/update_banner.dart';
import 'package:provider/provider.dart';

class _FailingBackup extends BackupController {
  _FailingBackup(DatabaseService database, Directory directory)
      : super(database, AppSettingsController(database.settings),
            servizio: BackupService(database, cartella: directory));

  int attempts = 0;

  @override
  Future<void> primaDiAggiornare() async {
    attempts++;
  }

  @override
  String get errore => 'Copia non riuscita.';
}

void main() {
  testWidgets('mostra il banner ma non apre GitHub se il backup fallisce',
      (tester) async {
    const channel = MethodChannel('planner/updates');
    final messages = tester.binding.defaultBinaryMessenger;
    var opened = false;
    messages.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRelease') opened = true;
      return true;
    });
    addTearDown(() => messages.setMockMethodCallHandler(channel, null));

    final temp = Directory.systemTemp.createTempSync('acta-update-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final db = DatabaseService();
    await tester.runAsync(() => db.init(dbPath: ':memory:'));
    addTearDown(db.close);
    final backup = _FailingBackup(db, temp);
    addTearDown(backup.dispose);

    const tag = 'v1.3.0-build.250';
    const filename = 'acta-$tag-android-arm64.apk';
    final updates = UpdateController(fetch: (installed) async {
      return GitHubUpdate.fromJson({
        'tag_name': tag,
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': filename,
            'state': 'uploaded',
            'size': 32000000,
            'digest': 'sha256:${'a' * 64}',
            'browser_download_url':
                'https://github.com/Call-me-ste/Acta/releases/download/$tag/$filename',
          },
        ],
      }, installedBuild: installed);
    });
    addTearDown(updates.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<BackupController>.value(value: backup),
        Provider.value(value: NoteAttachmentStore(db, temp)),
      ],
      child:
          MaterialApp(home: Scaffold(body: UpdateBanner(controller: updates))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiornamento disponibile'));
    await tester.pumpAndSettle();
    expect(backup.attempts, 1);
    expect(find.text('Copia non riuscita.'), findsOneWidget);
    expect(opened, isFalse);
  });
}
