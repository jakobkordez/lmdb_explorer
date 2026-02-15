import 'dart:typed_data';

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

  /// Ordered list of all keys in the currently selected database.
  /// Enables O(1) positional lookups and O(log n) cursor seeks.
  final List<Uint8List> keyIndex;

  /// Search results (populated only during an active search).
  final List<DatabaseEntry> searchResults;

  /// The current search query (empty = no search active).
  final String searchQuery;

  /// Whether a loading operation is in progress (key index building, search).
  final bool isLoading;

  const ExplorerLoaded({
    required this.environmentPath,
    required this.databaseNames,
    required this.selectedDatabase,
    this.selectedDatabaseInfo,
    this.keyIndex = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.isLoading = false,
  });

  ExplorerLoaded copyWith({
    String? environmentPath,
    List<String>? databaseNames,
    String? Function()? selectedDatabase,
    DatabaseInfo? Function()? selectedDatabaseInfo,
    List<Uint8List>? keyIndex,
    List<DatabaseEntry>? searchResults,
    String? searchQuery,
    bool? isLoading,
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
      keyIndex: keyIndex ?? this.keyIndex,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    environmentPath,
    databaseNames,
    selectedDatabase,
    selectedDatabaseInfo,
    // Use identity hash to avoid expensive deep comparison of large lists.
    identityHashCode(keyIndex),
    identityHashCode(searchResults),
    searchQuery,
    isLoading,
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
