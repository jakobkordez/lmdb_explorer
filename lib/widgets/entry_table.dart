import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/entry_viewer/entry_viewer_state.dart';
import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_event.dart';
import '../models/database_entry.dart';
import 'empty_state.dart';

class EntryTable extends StatefulWidget {
  final List<DatabaseEntry> entries;
  final bool isLoading;
  final bool hasMore;
  final String searchQuery;
  final int? totalEntries;

  const EntryTable({
    super.key,
    required this.entries,
    required this.isLoading,
    required this.hasMore,
    required this.searchQuery,
    this.totalEntries,
  });

  @override
  State<EntryTable> createState() => _EntryTableState();
}

class _EntryTableState extends State<EntryTable> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(EntryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the search controller with external state changes
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200 &&
        widget.hasMore &&
        !widget.isLoading) {
      context.read<ExplorerBloc>().add(const LoadMoreEntries());
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (query.isEmpty) {
        context.read<ExplorerBloc>().add(const ClearSearch());
      } else {
        context.read<ExplorerBloc>().add(SearchEntries(query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Search bar + status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search keys...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                context.read<ExplorerBloc>().add(
                                  const ClearSearch(),
                                );
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _buildStatusText(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '#',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Key',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Text(
                  'Value',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Size',
                  textAlign: TextAlign.end,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Entry list
        Expanded(
          child: widget.entries.isEmpty && !widget.isLoading
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No Entries',
                  subtitle: 'This database contains no entries.',
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.entries.length + (widget.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= widget.entries.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return _EntryRow(
                      entry: widget.entries[index],
                      index: index,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _buildStatusText() {
    final count = widget.entries.length;
    final total = widget.totalEntries;
    if (widget.searchQuery.isNotEmpty) {
      return '$count result(s)';
    }
    if (total != null) {
      return '$count / $total entries';
    }
    return '$count entries';
  }
}

class _EntryRow extends StatelessWidget {
  final DatabaseEntry entry;
  final int index;

  const _EntryRow({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<EntryViewerCubit, EntryViewerState>(
      builder: (context, viewerState) {
        final isSelected = viewerState.selectedEntry == entry;

        return InkWell(
          onTap: () => context.read<EntryViewerCubit>().selectEntry(entry),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : index.isOdd
                  ? colorScheme.surfaceContainerLow.withValues(alpha: 0.3)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.keyDisplay,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Consolas',
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.valuePreview,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _formatSize(entry.value.length),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
