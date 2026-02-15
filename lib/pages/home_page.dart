import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_event.dart';
import '../bloc/explorer/explorer_state.dart';
import '../widgets/database_sidebar.dart';
import '../widgets/empty_state.dart';
import '../widgets/entry_detail_panel.dart';
import '../widgets/entry_table.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openEnvironment(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select LMDB Environment Directory',
    );

    if (result != null && context.mounted) {
      context.read<EntryViewerCubit>().clearSelection();
      context.read<ExplorerBloc>().add(OpenEnvironment(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ExplorerBloc, ExplorerState>(
          builder: (context, state) {
            if (state is ExplorerLoaded) {
              return Row(
                children: [
                  const Icon(Icons.storage, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      state.environmentPath,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              );
            }
            return const Text('LMDB Explorer');
          },
        ),
        actions: [
          BlocBuilder<ExplorerBloc, ExplorerState>(
            builder: (context, state) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openEnvironment(context),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open'),
                  ),
                  if (state is ExplorerLoaded) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<EntryViewerCubit>().clearSelection();
                        context.read<ExplorerBloc>().add(
                          const CloseEnvironment(),
                        );
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(width: 12),
        ],
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: BlocBuilder<ExplorerBloc, ExplorerState>(
        builder: (context, state) {
          return switch (state) {
            ExplorerInitial() => const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No Environment Open',
              subtitle: 'Click "Open" to select an LMDB environment directory.',
            ),
            ExplorerLoading(:final path) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Opening $path...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            ExplorerLoaded() => _LoadedLayout(state: state),
            ExplorerError(:final message, :final previousState) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      message,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (previousState != null)
                          OutlinedButton(
                            onPressed: () {
                              // Re-select the database to retry
                              context.read<ExplorerBloc>().add(
                                SelectDatabase(previousState.selectedDatabase),
                              );
                            },
                            child: const Text('Retry'),
                          ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => _openEnvironment(context),
                          child: const Text('Open Another'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          };
        },
      ),
    );
  }

}

class _LoadedLayout extends StatefulWidget {
  final ExplorerLoaded state;

  const _LoadedLayout({required this.state});

  @override
  State<_LoadedLayout> createState() => _LoadedLayoutState();
}

class _LoadedLayoutState extends State<_LoadedLayout> {
  static const _minDetailWidth = 300.0;
  static const _maxDetailWidth = 800.0;
  static const _defaultDetailWidth = 450.0;

  double _detailWidth = _defaultDetailWidth;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = widget.state;

    return Row(
      children: [
        // Left panel: Database sidebar
        SizedBox(
          width: 220,
          child: DatabaseSidebar(
            databaseNames: state.databaseNames,
            selectedDatabase: state.selectedDatabase,
            environmentPath: state.environmentPath,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Center panel: Entry table
        Expanded(
          child: EntryTable(
            keyIndex: state.keyIndex,
            searchResults: state.searchResults,
            selectedDatabase: state.selectedDatabase,
            searchQuery: state.searchQuery,
            isLoading: state.isLoading,
          ),
        ),
        // Draggable resize handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragStart: (_) =>
                setState(() => _isDragging = true),
            onHorizontalDragUpdate: (details) {
              setState(() {
                _detailWidth = (_detailWidth - details.delta.dx)
                    .clamp(_minDetailWidth, _maxDetailWidth);
              });
            },
            onHorizontalDragEnd: (_) =>
                setState(() => _isDragging = false),
            child: Container(
              width: 5,
              color: _isDragging
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        // Right panel: Entry detail
        SizedBox(width: _detailWidth, child: const EntryDetailPanel()),
      ],
    );
  }
}
