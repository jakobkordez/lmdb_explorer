import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lmdb_explorer/services/recent_databases_service.dart';

part 'recent_databases_state.dart';

class RecentDatabasesCubit extends Cubit<RecentDatabasesState> {
  final RecentDatabasesService recentDatabasesService;

  RecentDatabasesCubit(this.recentDatabasesService)
    : super(RecentDatabasesInitial()) {
    loadRecentDatabases();
  }

  Future<void> loadRecentDatabases() async {
    final paths = await recentDatabasesService.getPaths();
    emit(RecentDatabasesLoaded(paths));
  }

  Future<void> pushRecentDatabase(String path) async {
    final paths = await recentDatabasesService.add(path);
    emit(RecentDatabasesLoaded(paths));
  }

  Future<void> removeRecentDatabase(String path) async {
    final paths = await recentDatabasesService.remove(path);
    emit(RecentDatabasesLoaded(paths));
  }
}
