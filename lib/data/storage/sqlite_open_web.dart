import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openWorkoutDatabase({String? databasePath}) =>
    databaseFactoryFfiWeb.openDatabase(
      databasePath ?? 'pace_workouts_v2.sqlite',
      options: OpenDatabaseOptions(version: 1),
    );
