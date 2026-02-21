part of 'recent_databases_cubit.dart';

sealed class RecentDatabasesState extends Equatable {
  const RecentDatabasesState();

  @override
  List<Object> get props => [];
}

final class RecentDatabasesInitial extends RecentDatabasesState {}

final class RecentDatabasesLoaded extends RecentDatabasesState {
  final List<String> paths;

  const RecentDatabasesLoaded(this.paths);

  @override
  List<Object> get props => [paths];
}
