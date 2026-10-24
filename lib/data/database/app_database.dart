import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

class AppDatabase {
  AppDatabase._();

  static const int version = 4;
  static const String fileName = 'fitlab.db';

  /// Mobile keeps the original sqflite location so existing data is found.
  /// Desktop uses the app support folder instead of the ffi default, which
  /// lives inside the working directory.
  static Future<String> defaultPath() async {
    if (Platform.isWindows || Platform.isLinux) {
      final dir = await getApplicationSupportDirectory();
      return p.join(dir.path, fileName);
    }
    return p.join(await getDatabasesPath(), fileName);
  }

  static Future<Database> open({
    required String path,
    DatabaseFactory? factory,
    bool singleInstance = true,
  }) {
    return (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var v = oldVersion + 1; v <= newVersion; v++) {
            await migrations[v]?.call(db);
          }
        },
      ),
    );
  }
}
