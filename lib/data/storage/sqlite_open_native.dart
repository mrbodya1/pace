import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<mobile.Database> openWorkoutDatabase({String? databasePath}) async {
  final mobile.DatabaseFactory factory;
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    factory = mobile.databaseFactory;
  } else {
    ffi.sqfliteFfiInit();
    factory = ffi.databaseFactoryFfi;
  }
  return factory.openDatabase(
    databasePath ??
        path.join(await factory.getDatabasesPath(), 'pace_workouts_v2.sqlite'),
    options: mobile.OpenDatabaseOptions(version: 1),
  );
}
