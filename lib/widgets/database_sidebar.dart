import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_event.dart';
import '../bloc/explorer/explorer_state.dart';
import '../services/lmdb_service.dart';
import 'stats_dialog.dart';

class DatabaseSidebar extends StatelessWidget {
  final List<String> databaseNames;
  final String? selectedDatabase;
  final String environmentPath;
  final VoidCallback onClose;

  const DatabaseSidebar({
    super.key,
    required this.databaseNames,
    required this.selectedDatabase,
    required this.environmentPath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.dns_outlined, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Databases',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              _HeaderIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close environment',
                onPressed: onClose,
              ),
              const SizedBox(width: 2),
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Environment Stats',
                  onPressed: () => _showEnvironmentStats(context),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Default database entry
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _DatabaseTile(
                name: null,
                isSelected: selectedDatabase == null,
                onTap: () => _selectDatabase(context, null),
              ),
              if (databaseNames.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    'NAMED DATABASES',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ...databaseNames.map(
                  (name) => _DatabaseTile(
                    name: name,
                    isSelected: selectedDatabase == name,
                    onTap: () => _selectDatabase(context, name),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Footer with count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: colorScheme.surfaceContainerLow,
          child: Text(
            '${databaseNames.length + 1} database(s)',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  void _selectDatabase(BuildContext context, String? dbName) {
    context.read<EntryViewerCubit>().clearSelection();
    context.read<ExplorerBloc>().add(SelectDatabase(dbName));
  }

  void _showEnvironmentStats(BuildContext context) {
    final state = context.read<ExplorerBloc>().state;
    if (state is ExplorerLoaded) {
      final lmdbService = context.read<LmdbService>();
      final explorerBloc = context.read<ExplorerBloc>();
      showDialog(
        context: context,
        builder: (_) => RepositoryProvider.value(
          value: lmdbService,
          child: BlocProvider.value(
            value: explorerBloc,
            child: StatsDialog(environmentPath: state.environmentPath),
          ),
        ),
      );
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 28,
        width: 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 16,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _DatabaseTile extends StatelessWidget {
  final String? name;
  final bool isSelected;
  final VoidCallback onTap;

  const _DatabaseTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        selected: isSelected,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        leading: Icon(
          name == null ? Icons.table_chart : Icons.table_chart_outlined,
          size: 18,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          name ?? '(default)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontStyle: name == null ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
