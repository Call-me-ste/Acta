import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const deviceStorageFullMessage =
    'Spazio sul dispositivo esaurito. Libera spazio e riprova.';

bool isDeviceStorageFull(Object error) => switch (error) {
      SqliteException(resultCode: 13) => true,
      FileSystemException(osError: final osError?) => Platform.isWindows
          ? osError.errorCode == 112 || osError.errorCode == 39
          : osError.errorCode == 28,
      _ => false,
    };
