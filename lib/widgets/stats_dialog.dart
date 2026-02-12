import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_state.dart';
import '../models/database_info.dart';
import '../services/lmdb_service.dart';

class StatsDialog extends StatelessWidget {
  final String environmentPath;

  const StatsDialog({super.key, required this.environmentPath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Environment Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                environmentPath,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Flexible(child: _StatsContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatefulWidget {
  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  Map<String, DatabaseInfo>? _allStats;
  DatabaseInfo? _envInfo;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Access the LmdbService through the bloc
    final bloc = context.read<ExplorerBloc>();
    final state = bloc.state;
    if (state is! ExplorerLoaded) return;

    try {
      // We need direct access to the service. We'll get stats
      // for each database listed in the state.
      final service = _getService(bloc);
      if (service == null) return;

      final envInfo = await service.getEnvironmentInfo();
      final allStats = <String, DatabaseInfo>{};

      // Default database
      final defaultInfo = await service.getDatabaseInfo(null);
      allStats['(default)'] = defaultInfo;

      for (final dbName in state.databaseNames) {
        final info = await service.getDatabaseInfo(dbName);
        allStats[dbName] = info;
      }

      if (mounted) {
        setState(() {
          _envInfo = envInfo;
          _allStats = allStats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  LmdbService? _getService(ExplorerBloc bloc) {
    try {
      return RepositoryProvider.of<LmdbService>(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_envInfo != null) ...[
            _SectionTitle('Environment'),
            _StatsTable(info: _envInfo!),
            const SizedBox(height: 16),
            const Divider(),
          ],
          if (_allStats != null)
            ..._allStats!.entries.map((e) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(e.key),
                  _StatsTable(info: e.value),
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final DatabaseInfo info;
  const _StatsTable({required this.info});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = [
      ('Entries', '${info.entries}'),
      ('Page Size', '${info.pageSize} bytes'),
      ('B+ Tree Depth', '${info.depth}'),
      ('Branch Pages', '${info.branchPages}'),
      ('Leaf Pages', '${info.leafPages}'),
      ('Overflow Pages', '${info.overflowPages}'),
      ('Est. Size', _formatSize(info.estimatedSize)),
    ];

    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
      children: rows.map((row) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                row.$1,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                row.$2,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
