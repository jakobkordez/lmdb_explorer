import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/entry_viewer/entry_viewer_cubit.dart';
import 'bloc/explorer/explorer_bloc.dart';
import 'pages/home_page.dart';
import 'services/lmdb_service.dart';

class LmdbExplorerApp extends StatefulWidget {
  const LmdbExplorerApp({super.key});

  @override
  State<LmdbExplorerApp> createState() => _LmdbExplorerAppState();
}

class _LmdbExplorerAppState extends State<LmdbExplorerApp> {
  late final LmdbService _lmdbService;

  @override
  void initState() {
    super.initState();
    _lmdbService = LmdbService();
  }

  @override
  void dispose() {
    _lmdbService.closeEnvironment();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _lmdbService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ExplorerBloc(lmdbService: _lmdbService)),
          BlocProvider(create: (_) => EntryViewerCubit()),
        ],
        child: MaterialApp(
          title: 'LMDB Explorer',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Segoe UI',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4CAF50),
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
