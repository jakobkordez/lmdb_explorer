import 'package:equatable/equatable.dart';

import '../../models/database_entry.dart';
import '../../models/database_info.dart';

sealed class ExplorerState extends Equatable {
  const ExplorerState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no environment is open.
class ExplorerInitial extends ExplorerState {
  const ExplorerInitial();
}

/// An environment is being opened.
class ExplorerLoading extends ExplorerState {
  final String path;
  const ExplorerLoading(this.path);

  @override
  List<Object?> get props => [path];
}

/// An environment is open and data is available.
class ExplorerLoaded extends ExplorerState {
  /// Path of the open environment.
  final String environmentPath;

  /// All named databases found in the environment.
  final List<String> databaseNames;

  /// The currently selected database name (null = default db).
  final String? selectedDatabase;

  /// Info/stats for the currently selected database.
  final DatabaseInfo? selectedDatabaseInfo;

  /// The loaded entries for the current database.
  final List<DatabaseEntry> entries;

  /// Whether more entries can be loaded (pagination).
  final bool hasMoreEntries;

  /// The current search query (empty = no search active).
  final String searchQuery;

  /// Whether entries are currently being loaded/searched.
  final bool isLoadingEntries;

  const ExplorerLoaded({
    required this.environmentPath,
    required this.databaseNames,
    required this.selectedDatabase,
    this.selectedDatabaseInfo,
    this.entries = const [],
    this.hasMoreEntries = false,
    this.searchQuery = '',
    this.isLoadingEntries = false,
  });

  ExplorerLoaded copyWith({
    String? environmentPath,
    List<String>? databaseNames,
    String? Function()? selectedDatabase,
    DatabaseInfo? Function()? selectedDatabaseInfo,
    List<DatabaseEntry>? entries,
    bool? hasMoreEntries,
    String? searchQuery,
    bool? isLoadingEntries,
  }) {
    return ExplorerLoaded(
      environmentPath: environmentPath ?? this.environmentPath,
      databaseNames: databaseNames ?? this.databaseNames,
      selectedDatabase: selectedDatabase != null
          ? selectedDatabase()
          : this.selectedDatabase,
      selectedDatabaseInfo: selectedDatabaseInfo != null
          ? selectedDatabaseInfo()
          : this.selectedDatabaseInfo,
      entries: entries ?? this.entries,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoadingEntries: isLoadingEntries ?? this.isLoadingEntries,
    );
  }

  @override
  List<Object?> get props => [
    environmentPath,
    databaseNames,
    selectedDatabase,
    selectedDatabaseInfo,
    entries,
    hasMoreEntries,
    searchQuery,
    isLoadingEntries,
  ];
}

/// An error occurred.
class ExplorerError extends ExplorerState {
  final String message;

  /// The previous loaded state, if any, to allow recovery.
  final ExplorerLoaded? previousState;

  const ExplorerError(this.message, {this.previousState});

  @override
  List<Object?> get props => [message, previousState];
}
