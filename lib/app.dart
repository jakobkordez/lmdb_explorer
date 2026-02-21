import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lmdb_explorer/bloc/recent_databases/recent_databases_cubit.dart';

import 'bloc/entry_viewer/entry_viewer_cubit.dart';
import 'bloc/explorer/explorer_bloc.dart';
import 'pages/home_page.dart';
import 'services/lmdb_service.dart';
import 'services/recent_databases_service.dart';

class LmdbExplorerApp extends StatelessWidget {
  const LmdbExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => LmdbService(),
          dispose: (s) => s.closeEnvironment(),
        ),
        RepositoryProvider(create: (_) => RecentDatabasesService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                RecentDatabasesCubit(context.read<RecentDatabasesService>()),
          ),
          BlocProvider(
            create: (context) =>
                ExplorerBloc(lmdbService: context.read<LmdbService>()),
          ),
          BlocProvider(create: (_) => EntryViewerCubit()),
        ],
        child: MaterialApp(
          title: 'LMDB Explorer',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF009687),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Segoe UI',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF009687),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Segoe UI',
          ),
          themeMode: ThemeMode.light,
          home: const HomePage(),
        ),
      ),
    );
  }
}
