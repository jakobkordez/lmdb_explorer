import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lmdb_explorer/bloc/recent_databases/recent_databases_cubit.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_event.dart';
import '../bloc/explorer/explorer_state.dart';
import '../widgets/database_sidebar.dart';
import '../widgets/desktop_app_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/entry_detail_panel.dart';
import '../widgets/entry_table.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openEnvironment(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select LMDB Environment Directory',
    );

    if (result != null && context.mounted) _openPath(context, result);
  }

  void _openPath(BuildContext context, String path) {
    context.read<EntryViewerCubit>().clearSelection();
    context.read<RecentDatabasesCubit>().pushRecentDatabase(path);
    context.read<ExplorerBloc>().add(OpenEnvironment(path));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DesktopAppBar(),
      body: BlocBuilder<ExplorerBloc, ExplorerState>(
        builder: (context, state) {
          return switch (state) {
            ExplorerInitial() => _InitialScreen(
              onOpenEnvironment: () => _openEnvironment(context),
              onOpenPath: (path) => _openPath(context, path),
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
            ExplorerError(:final message) => Center(
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
                        FilledButton(
                          onPressed: () => context.read<ExplorerBloc>().add(
                            const CloseEnvironment(),
                          ),
                          child: const Text('Back'),
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

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left panel: Database sidebar
          SizedBox(
            width: 220,
            child: DatabaseSidebar(
              databaseNames: state.databaseNames,
              selectedDatabase: state.selectedDatabase,
              environmentPath: state.environmentPath,
              onClose: () {
                context.read<EntryViewerCubit>().clearSelection();
                context.read<ExplorerBloc>().add(const CloseEnvironment());
              },
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
              onHorizontalDragStart: (_) => setState(() => _isDragging = true),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _detailWidth = (_detailWidth - details.delta.dx).clamp(
                    _minDetailWidth,
                    _maxDetailWidth,
                  );
                });
              },
              onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
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
      ),
    );
  }
}

class _InitialScreen extends StatelessWidget {
  final VoidCallback onOpenEnvironment;
  final ValueChanged<String> onOpenPath;

  const _InitialScreen({
    required this.onOpenEnvironment,
    required this.onOpenPath,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget child;
        if (constraints.maxWidth <= 850) {
          child = ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              _left(),
              Divider(
                height: 100,
                indent: 50,
                endIndent: 50,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: Center(child: _right(context)),
              ),
            ],
          );
        } else {
          child = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SizedBox()),
              // Left half: open environment prompt
              SizedBox(width: 400, child: _left()),
              Expanded(
                child: SizedBox(
                  height: 200,
                  child: VerticalDivider(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Right half: recently opened databases
              SizedBox(width: 400, child: _right(context)),
              Expanded(child: SizedBox()),
            ],
          );
        }

        return Center(child: child);
      },
    );
  }

  Widget _left() {
    return EmptyState(
      icon: Icons.folder_open_outlined,
      title: 'No Environment Open',
      subtitle: 'Select an LMDB environment directory to explore.',
      action: FilledButton.icon(
        onPressed: onOpenEnvironment,
        icon: const Icon(Icons.folder_open_rounded, size: 20),
        label: const Text('Open environment'),
      ),
    );
  }

  Widget _right(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<RecentDatabasesCubit, RecentDatabasesState>(
      builder: (context, state) {
        if (state is! RecentDatabasesLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final paths = state.paths;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recently Opened',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (paths.isEmpty)
              Text(
                'No recent environments',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              )
            else
              ...paths.map((path) {
                final exists = Directory(path).existsSync();

                return _RecentItem(
                  path: path,
                  dirName: path.split(RegExp(r'[/\\]')).last,
                  exists: exists,
                  onTap: exists ? () => onOpenPath(path) : null,
                  onRemove: () => context
                      .read<RecentDatabasesCubit>()
                      .removeRecentDatabase(path),
                );
              }),
          ],
        );
      },
    );
  }
}

class _RecentItem extends StatefulWidget {
  final String path;
  final String dirName;
  final bool exists;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _RecentItem({
    required this.path,
    required this.dirName,
    required this.exists,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_RecentItem> createState() => _RecentItemState();
}

class _RecentItemState extends State<_RecentItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        enabled: widget.exists,
        onTap: widget.onTap,
        hoverColor: colorScheme.primary.withValues(alpha: 0.06),
        leading: Icon(
          Icons.folder_outlined,
          size: 20,
          color: widget.exists
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        title: Text(
          widget.dirName,
          style: textTheme.bodyMedium?.copyWith(
            color: widget.exists
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          widget.path,
          style: textTheme.bodySmall?.copyWith(
            color: widget.exists
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _hovering
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Remove from recents',
                onPressed: widget.onRemove,
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}
