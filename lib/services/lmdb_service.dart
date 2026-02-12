import 'dart:typed_data';

import 'package:dart_lmdb2/lmdb.dart';

import '../models/database_entry.dart';
import '../models/database_info.dart';

/// Result of a paginated entry query.
class EntryPage {
  final List<DatabaseEntry> entries;
  final bool hasMore;

  const EntryPage({required this.entries, required this.hasMore});
}

/// Service that wraps the dart_lmdb2 [LMDB] class for read-only browsing.
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

  /// Fetches a page of entries from [dbName] using cursor iteration.
  ///
  /// [offset] is the number of entries to skip.
  /// [limit] is the maximum number of entries to return.
  Future<EntryPage> getEntries(
    String? dbName, {
    int offset = 0,
    int limit = 100,
  }) async {
    _ensureOpen();

    final txn = await _db!.txnStart(flags: LMDBFlagSet.readOnly);
    try {
      final cursor = await _db!.cursorOpen(txn, dbName: dbName);
      try {
        final entries = <DatabaseEntry>[];

        // Position at first entry
        var entry = await _db!.cursorGet(cursor, null, CursorOp.first);

        // Skip [offset] entries
        var skipped = 0;
        while (entry != null && skipped < offset) {
          entry = await _db!.cursorGet(cursor, null, CursorOp.next);
          skipped++;
        }

        // Collect up to [limit] entries
        while (entry != null && entries.length < limit) {
          entries.add(
            DatabaseEntry(
              key: Uint8List.fromList(entry.key),
              value: Uint8List.fromList(entry.data),
            ),
          );
          entry = await _db!.cursorGet(cursor, null, CursorOp.next);
        }

        // Check if there are more entries after this page
        final hasMore = entry != null;

        return EntryPage(entries: entries, hasMore: hasMore);
      } finally {
        _db!.cursorClose(cursor);
      }
    } finally {
      await _db!.txnAbort(txn);
    }
  }

  /// Searches entries in [dbName] whose key contains [query] (UTF-8 comparison).
  ///
  /// This scans all entries, so it may be slow for large databases.
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
      await _db!.txnAbort(txn);
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
