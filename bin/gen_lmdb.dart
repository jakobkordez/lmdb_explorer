import 'dart:math';

import 'package:dart_lmdb/dart_lmdb.dart';

Future<void> main() async {
  final r = Random();

  final db = LMDB();
  await db.init(
    'lmdb_data_multi',
    config: LMDBInitConfig(
      mapSize: 1024 * 1024 * 1024, // 1GB
      maxDbs: 5,
    ),
  );

  {
    final txn = await db.txnStart();
    try {
      for (var i = 0; i < 1000000; i++) {
        await db.put(
          txn,
          'key_${i.toString().padLeft(6, '0')}',
          'value_${r.nextInt(1000000)}'.codeUnits,
          dbName: 'string_db',
        );
      }
      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }
  }

  {
    final txn = await db.txnStart();
    try {
      for (var i = 0; i < 1000000; i++) {
        await db.put(
          txn,
          'key_${i.toString().padLeft(6, '0')}',
          List.generate(r.nextInt(100) + 10, (index) => r.nextInt(256)),
          dbName: 'hex_db',
        );
      }
      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }
  }

  {
    final txn = await db.txnStart();
    try {
      for (var i = 2; i <= 1024 * 1024; i *= 2) {
        await db.put(
          txn,
          'key_${i.toString().padLeft(7, '0')}',
          List.generate(i, (index) => r.nextInt(256)),
          dbName: 'size_db',
        );
      }
      await db.txnCommit(txn);
    } catch (e) {
      await db.txnAbort(txn);
      rethrow;
    }
  }

  db.close();
}
