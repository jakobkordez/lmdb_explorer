import 'package:equatable/equatable.dart';

sealed class ExplorerEvent extends Equatable {
  const ExplorerEvent();

  @override
  List<Object?> get props => [];
}

/// User selected a directory to open as an LMDB environment.
class OpenEnvironment extends ExplorerEvent {
  final String path;
  const OpenEnvironment(this.path);

  @override
  List<Object?> get props => [path];
}

/// User selected a named database from the sidebar.
/// [dbName] is null for the default (unnamed) database.
class SelectDatabase extends ExplorerEvent {
  final String? dbName;
  const SelectDatabase(this.dbName);

  @override
  List<Object?> get props => [dbName];
}

/// User typed a search query to filter entries by key.
class SearchEntries extends ExplorerEvent {
  final String query;
  const SearchEntries(this.query);

  @override
  List<Object?> get props => [query];
}

/// Clear the current search and reload entries.
class ClearSearch extends ExplorerEvent {
  const ClearSearch();
}

/// Close the current environment.
class CloseEnvironment extends ExplorerEvent {
  const CloseEnvironment();
}
