import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/database_entry.dart';
import '../../services/lmdb_service.dart';
import 'explorer_event.dart';
import 'explorer_state.dart';

class ExplorerBloc extends Bloc<ExplorerEvent, ExplorerState> {
  final LmdbService _lmdbService;

  ExplorerBloc({required LmdbService lmdbService})
    : _lmdbService = lmdbService,
      super(const ExplorerInitial()) {
    on<OpenEnvironment>(_onOpenEnvironment);
    on<SelectDatabase>(_onSelectDatabase);
    on<SearchEntries>(_onSearchEntries);
    on<ClearSearch>(_onClearSearch);
    on<CloseEnvironment>(_onCloseEnvironment);
  }

  Future<void> _onOpenEnvironment(
    OpenEnvironment event,
    Emitter<ExplorerState> emit,
  ) async {
    emit(ExplorerLoading(event.path));

    try {
      await _lmdbService.openEnvironment(event.path);
      final databases = await _lmdbService.listDatabases();

      emit(
        ExplorerLoaded(
          environmentPath: event.path,
          databaseNames: databases,
          selectedDatabase: null,
        ),
      );

      // Auto-load the default database
      add(const SelectDatabase(null));
    } catch (e) {
      emit(ExplorerError('Failed to open environment: $e'));
    }
  }

  Future<void> _onSelectDatabase(
    SelectDatabase event,
    Emitter<ExplorerState> emit,
  ) async {
    final current = state;
    if (current is! ExplorerLoaded) return;

    emit(
      current.copyWith(
        selectedDatabase: () => event.dbName,
        keyIndex: const [],
        searchResults: const [],
        searchQuery: '',
        isLoading: true,
      ),
    );

    try {
      final info = await _lmdbService.getDatabaseInfo(event.dbName);
      final keyIndex = await _lmdbService.buildKeyIndex(event.dbName);

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(
        loaded.copyWith(
          selectedDatabaseInfo: () => info,
          keyIndex: keyIndex,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(ExplorerError('Failed to load database: $e'));
    }
  }

  Future<void> _onSearchEntries(
    SearchEntries event,
    Emitter<ExplorerState> emit,
  ) async {
    final current = state;
    if (current is! ExplorerLoaded) return;

    if (event.query.isEmpty) {
      add(const ClearSearch());
      return;
    }

    emit(current.copyWith(searchQuery: event.query, isLoading: true));

    try {
      List<DatabaseEntry> results;

      if (current.keyIndex.isNotEmpty) {
        // Fast path: filter keys in memory, then fetch values only for matches.
        results = await _searchWithKeyIndex(
          current.selectedDatabase,
          current.keyIndex,
          event.query,
        );
      } else {
        // Fallback: full cursor scan (key index not yet built).
        results = await _lmdbService.searchEntries(
          current.selectedDatabase,
          event.query,
        );
      }

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(loaded.copyWith(searchResults: results, isLoading: false));
    } catch (e) {
      emit(ExplorerError('Search failed: $e'));
    }
  }

  /// Searches by filtering the key index in memory (no DB I/O for non-matches),
  /// then fetches full entries only for matching keys.
  Future<List<DatabaseEntry>> _searchWithKeyIndex(
    String? dbName,
    List<Uint8List> keyIndex,
    String query,
  ) async {
    final queryLower = query.toLowerCase();

    // Phase 1: filter keys in memory — very fast.
    final matchingKeys = <Uint8List>[];
    for (final key in keyIndex) {
      final keyStr = DatabaseEntry.keyDisplayForBytes(key).toLowerCase();
      if (keyStr.contains(queryLower)) {
        matchingKeys.add(key);
      }
    }

    // Phase 2: fetch full entries (key + value) for matching keys only.
    return _lmdbService.getEntriesByKeys(dbName, matchingKeys);
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<ExplorerState> emit,
  ) async {
    final current = state;
    if (current is! ExplorerLoaded) return;

    emit(current.copyWith(searchQuery: '', searchResults: const []));
  }

  Future<void> _onCloseEnvironment(
    CloseEnvironment event,
    Emitter<ExplorerState> emit,
  ) async {
    await _lmdbService.closeEnvironment();
    emit(const ExplorerInitial());
  }

  @override
  Future<void> close() async {
    await _lmdbService.closeEnvironment();
    return super.close();
  }
}
