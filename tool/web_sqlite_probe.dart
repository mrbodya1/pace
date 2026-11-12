import 'dart:js_interop';

import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

@JS('document.body.textContent')
external set result(String value);
Future<void> main() async {
  try {
    final db = await databaseFactoryFfiWeb.openDatabase('pace_probe_v2.sqlite');
    await db.execute(
      'CREATE TABLE IF NOT EXISTS probe(id INTEGER PRIMARY KEY,value TEXT)',
    );
    await db.transaction((tx) async {
      await tx.rawInsert('INSERT OR REPLACE INTO probe(id,value) VALUES(1,?)', [
        'sqlite-web-v2',
      ]);
    });
    await db.close();
    final reopened = await databaseFactoryFfiWeb.openDatabase(
      'pace_probe_v2.sqlite',
    );
    final rows = await reopened.rawQuery('SELECT value FROM probe WHERE id=1');
    if (rows.single['value'] != 'sqlite-web-v2') {
      throw StateError('Persistence failed');
    }
    await reopened.close();
    result = 'SQLITE_WEB_OK';
  } catch (e) {
    result = 'SQLITE_WEB_ERROR:$e';
  }
}
