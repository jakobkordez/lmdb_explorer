import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/lmdb_service.dart';
import 'explorer_event.dart';
import 'explorer_state.dart';

class ExplorerBloc extends Bloc<ExplorerEvent, ExplorerState> {
  final LmdbService _lmdbService;

  static const int _pageSize = 100;

  ExplorerBloc({required LmdbService lmdbService})
    : _lmdbService = lmdbService,
      super(const ExplorerInitial()) {
    on<OpenEnvironment>(_onOpenEnvironment);
    on<SelectDatabase>(_onSelectDatabase);
    on<LoadMoreEntries>(_onLoadMoreEntries);
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

      // Auto-load the default database entries
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
        entries: const [],
        hasMoreEntries: false,
        searchQuery: '',
        isLoadingEntries: true,
      ),
    );

    try {
      final info = await _lmdbService.getDatabaseInfo(event.dbName);
      final page = await _lmdbService.getEntries(
        event.dbName,
        offset: 0,
        limit: _pageSize,
      );

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(
        loaded.copyWith(
          selectedDatabaseInfo: () => info,
          entries: page.entries,
          hasMoreEntries: page.hasMore,
          isLoadingEntries: false,
        ),
      );
    } catch (e) {
      emit(
        ExplorerError('Failed to load database: $e', previousState: current),
      );
    }
  }

  Future<void> _onLoadMoreEntries(
    LoadMoreEntries event,
    Emitter<ExplorerState> emit,
  ) async {
    final current = state;
    if (current is! ExplorerLoaded) return;
    if (current.isLoadingEntries || !current.hasMoreEntries) return;
    if (current.searchQuery.isNotEmpty) return; // no pagination for search

    emit(current.copyWith(isLoadingEntries: true));

    try {
      final page = await _lmdbService.getEntries(
        current.selectedDatabase,
        offset: current.entries.length,
        limit: _pageSize,
      );

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(
        loaded.copyWith(
          entries: [...loaded.entries, ...page.entries],
          hasMoreEntries: page.hasMore,
          isLoadingEntries: false,
        ),
      );
    } catch (e) {
      emit(
        ExplorerError(
          'Failed to load more entries: $e',
          previousState: current,
        ),
      );
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

    emit(current.copyWith(searchQuery: event.query, isLoadingEntries: true));

    try {
      final results = await _lmdbService.searchEntries(
        current.selectedDatabase,
        event.query,
      );

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(
        loaded.copyWith(
          entries: results,
          hasMoreEntries: false,
          isLoadingEntries: false,
        ),
      );
    } catch (e) {
      emit(ExplorerError('Search failed: $e', previousState: current));
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<ExplorerState> emit,
  ) async {
    final current = state;
    if (current is! ExplorerLoaded) return;

    emit(
      current.copyWith(
        searchQuery: '',
        entries: const [],
        isLoadingEntries: true,
      ),
    );

    try {
      final page = await _lmdbService.getEntries(
        current.selectedDatabase,
        offset: 0,
        limit: _pageSize,
      );

      final loaded = state;
      if (loaded is! ExplorerLoaded) return;

      emit(
        loaded.copyWith(
          entries: page.entries,
          hasMoreEntries: page.hasMore,
          isLoadingEntries: false,
        ),
      );
    } catch (e) {
      emit(
        ExplorerError('Failed to reload entries: $e', previousState: current),
      );
    }
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
