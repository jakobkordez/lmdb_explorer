import 'dart:typed_data';

import 'package:dart_lmdb/dart_lmdb.dart';

import '../models/database_entry.dart';
import '../models/database_info.dart';

/// Service that wraps the flutter_lmdb2 [LMDB] class for read-only browsing.
class LmdbService {
  LMDB? _db;

  /// Whether an environment is currently open.
  bool get isOpen => _db != null && _db!.isInitialized;

  /// The currently open database instance (if any).
  LMDB? get db => _db;

  /// Opens an LMDB environment in read-only mode at [path].
  ///
  /// [maxDbs] controls the maximum number of named databases to support.
  Future<void> openEnvironment(String path, {int maxDbs = 128}) async {
    await closeEnvironment();

    _db = LMDB();
    await _db!.init(
      path,
      flags: LMDBFlagSet.readOnly,
      config: LMDBInitConfig(
        mapSize: 1024 * 1024, // 1 MB - fine for read-only access
        maxDbs: maxDbs,
      ),
    );
  }

  /// Lists all named databases in the current environment.
  Future<List<String>> listDatabases() async {
    _ensureOpen();
    return await _db!.listDatabases();
  }

  /// Returns [DatabaseInfo] for the given database.
  /// Pass null for the default (unnamed) database.
  Future<DatabaseInfo> getDatabaseInfo(String? dbName) async {
    _ensureOpen();
    final stats = await _db!.getStats(dbName: dbName);
    return DatabaseInfo(
      name: dbName,
      entries: stats.entries,
      pageSize: stats.pageSize,
      depth: stats.depth,
      branchPages: stats.branchPages,
      leafPages: stats.leafPages,
      overflowPages: stats.overflowPages,
    );
  }

  /// Returns environment-level statistics.
  Future<DatabaseInfo> getEnvironmentInfo() async {
    _ensureOpen();
    final stats = await _db!.getEnvironmentStats();
    return DatabaseInfo(
      name: null,
      entries: stats.entries,
      pageSize: stats.pageSize,
      depth: stats.depth,
      branchPages: stats.branchPages,
      leafPages: stats.leafPages,
      overflowPages: stats.overflowPages,
    );
  }

  /// Builds an ordered index of all keys in [dbName].
  ///
  /// This iterates through the entire database but only stores keys (not
  /// values). The resulting list maps positional index → key bytes, enabling
  /// O(1) index-to-key lookups and O(log n) cursor seeks via [getEntryRange].
  ///
  /// Uses [LMDB.getAllKeys] which performs the cursor iteration in a single
  /// synchronous FFI loop, avoiding per-entry async overhead and unnecessary
  /// value copying.
  Future<List<Uint8List>> buildKeyIndex(String? dbName) async {
    _ensureOpen();

    final txn = await _db!.txnStart(flags: LMDBFlagSet.readOnly);
    try {
      final keys = await _db!.getAllKeys(txn, dbName: dbName);
      // Commit (not abort) read-only transactions so that named-database
      // DBI handles opened during the txn are persisted to the environment
      // (mdb_dbis_update with keep=1 sets MDB_VALID in me_dbflags).
      // Aborting would clear DB_NEW handles, invalidating cached DBIs.
      await _db!.txnCommit(txn);
      return keys;
    } catch (e) {
      await _db!.txnAbort(txn);
      rethrow;
    }
  }

  /// Fetches entries for indices [startIndex] to [startIndex + count - 1]
  /// using the [keyIndex] to seek directly to the starting key.
  ///
  /// This opens a short-lived read transaction, seeks to the start key via
  /// [CursorOp.setKey] (O(log n)), then reads forward [count] entries.
  Future<List<DatabaseEntry>> getEntryRange(
    String? dbName,
    List<Uint8List> keyIndex,
    int startIndex,
    int count,
  ) async {
    _ensureOpen();
    if (startIndex < 0 || startIndex >= keyIndex.length) return [];

    final end = (startIndex + count).clamp(0, keyIndex.length);

    final txn = await _db!.txnStart(flags: LMDBFlagSet.readOnly);
    try {
      final cursor = await _db!.cursorOpen(txn, dbName: dbName);
      try {
        final entries = <DatabaseEntry>[];

        // Seek directly to the start key — O(log n)
        final startKey = keyIndex[startIndex];
        var entry = await _db!.cursorGet(cursor, startKey, CursorOp.setKey);
        if (entry == null) return [];

        entries.add(
          DatabaseEntry(
            key: Uint8List.fromList(entry.key),
            value: Uint8List.fromList(entry.data),
          ),
        );

        // Read forward for the remaining entries — O(count)
        for (var i = startIndex + 1; i < end; i++) {
          entry = await _db!.cursorGet(cursor, null, CursorOp.next);
          if (entry == null) break;
          entries.add(
            DatabaseEntry(
              key: Uint8List.fromList(entry.key),
              value: Uint8List.fromList(entry.data),
            ),
          );
        }

        return entries;
      } finally {
        _db!.cursorClose(cursor);
      }
    } finally {
      // Commit (not abort) read-only transactions so that named-database
      // DBI handles opened during the txn are persisted to the environment
      // (mdb_dbis_update with keep=1 sets MDB_VALID in me_dbflags).
      // Aborting would clear DB_NEW handles, invalidating cached DBIs.
      await _db!.txnCommit(txn);
    }
  }

  /// Fetches entries for a set of specific keys using cursor seeks.
  ///
  /// Each key is looked up individually via [CursorOp.setKey] (O(log n) each).
  /// This is efficient when the number of keys is small (e.g. search results).
  Future<List<DatabaseEntry>> getEntriesByKeys(
    String? dbName,
    List<Uint8List> keys,
  ) async {
    _ensureOpen();
    if (keys.isEmpty) return [];

    final txn = await _db!.txnStart(flags: LMDBFlagSet.readOnly);
    try {
      final cursor = await _db!.cursorOpen(txn, dbName: dbName);
      try {
        final entries = <DatabaseEntry>[];
        for (final key in keys) {
          final entry = await _db!.cursorGet(cursor, key, CursorOp.setKey);
          if (entry != null) {
            entries.add(
              DatabaseEntry(
                key: Uint8List.fromList(entry.key),
                value: Uint8List.fromList(entry.data),
              ),
            );
          }
        }
        return entries;
      } finally {
        _db!.cursorClose(cursor);
      }
    } finally {
      // Commit (not abort) read-only transactions so that named-database
      // DBI handles opened during the txn are persisted to the environment
      // (mdb_dbis_update with keep=1 sets MDB_VALID in me_dbflags).
      // Aborting would clear DB_NEW handles, invalidating cached DBIs.
      await _db!.txnCommit(txn);
    }
  }

  /// Searches entries in [dbName] whose key contains [query] (UTF-8 comparison).
  ///
  /// This scans all entries, so it may be slow for large databases.
  /// Prefer using [getEntriesByKeys] with a pre-filtered key index when
  /// a key index is available.
  /// [limit] caps the number of results returned.
  Future<List<DatabaseEntry>> searchEntries(
    String? dbName,
    String query, {
    int limit = 200,
  }) async {
    _ensureOpen();
    final queryLower = query.toLowerCase();

    final txn = await _db!.txnStart(flags: LMDBFlagSet.readOnly);
    try {
      final cursor = await _db!.cursorOpen(txn, dbName: dbName);
      try {
        final results = <DatabaseEntry>[];
        var entry = await _db!.cursorGet(cursor, null, CursorOp.first);

        while (entry != null && results.length < limit) {
          final dbEntry = DatabaseEntry(
            key: Uint8List.fromList(entry.key),
            value: Uint8List.fromList(entry.data),
          );

          // Match against key display (UTF-8 if valid, hex otherwise)
          final keyStr = dbEntry.keyDisplay.toLowerCase();
          if (keyStr.contains(queryLower)) {
            results.add(dbEntry);
          }

          entry = await _db!.cursorGet(cursor, null, CursorOp.next);
        }

        return results;
      } finally {
        _db!.cursorClose(cursor);
      }
    } finally {
      // Commit (not abort) read-only transactions so that named-database
      // DBI handles opened during the txn are persisted to the environment
      // (mdb_dbis_update with keep=1 sets MDB_VALID in me_dbflags).
      // Aborting would clear DB_NEW handles, invalidating cached DBIs.
      await _db!.txnCommit(txn);
    }
  }

  /// Closes the current environment and releases resources.
  Future<void> closeEnvironment() async {
    if (_db != null) {
      _db!.close();
      _db = null;
    }
  }

  void _ensureOpen() {
    if (_db == null || !_db!.isInitialized) {
      throw StateError('No LMDB environment is open.');
    }
  }
}
