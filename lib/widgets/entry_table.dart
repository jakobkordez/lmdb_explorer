import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/entry_viewer/entry_viewer_state.dart';
import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_event.dart';
import '../models/database_entry.dart';
import '../services/lmdb_service.dart';
import 'empty_state.dart';

class EntryTable extends StatefulWidget {
  /// Ordered keys for positional lookups (browsing mode).
  final List<Uint8List> keyIndex;

  /// Search results — fully loaded entries (search mode).
  final List<DatabaseEntry> searchResults;

  /// The currently selected database name (null = default).
  final String? selectedDatabase;

  /// Active search query (empty = browsing mode).
  final String searchQuery;

  /// Whether a top-level operation is in progress (key index build, search).
  final bool isLoading;

  const EntryTable({
    super.key,
    required this.keyIndex,
    required this.searchResults,
    required this.selectedDatabase,
    required this.searchQuery,
    required this.isLoading,
  });

  @override
  State<EntryTable> createState() => _EntryTableState();
}

class _EntryTableState extends State<EntryTable> {
  static const double _rowHeight = 34.0;
  static const int _fetchBatchSize = 200;
  static const int _bufferRows = 50;
  static const int _maxCacheSize = 1000;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _fetchDebounce;

  /// Sparse cache of fetched entries by their positional index.
  final Map<int, DatabaseEntry> _cache = {};

  /// Guard to prevent overlapping fetch calls.
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVisibleWindow();
    });
  }

  @override
  void didUpdateWidget(EntryTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync the search controller with external state changes.
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }

    // When the key index changes (different database), clear the cache and
    // scroll to top.
    if (!identical(widget.keyIndex, oldWidget.keyIndex)) {
      _cache.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _fetchVisibleWindow();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _fetchDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Scroll-driven on-demand fetching
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (widget.searchQuery.isNotEmpty) return;
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(
      const Duration(milliseconds: 16),
      _fetchVisibleWindow,
    );
  }

  Future<void> _fetchVisibleWindow() async {
    if (!mounted || !_scrollController.hasClients) return;
    if (widget.searchQuery.isNotEmpty) return;
    if (widget.keyIndex.isEmpty) return;
    if (_isFetching) return;

    final position = _scrollController.position;
    final firstVisible =
        (position.pixels / _rowHeight).floor().clamp(0, widget.keyIndex.length - 1);
    final lastVisible =
        ((position.pixels + position.viewportDimension) / _rowHeight)
            .ceil()
            .clamp(0, widget.keyIndex.length);

    final windowStart =
        (firstVisible - _bufferRows).clamp(0, widget.keyIndex.length);
    final windowEnd =
        (lastVisible + _bufferRows).clamp(0, widget.keyIndex.length);

    // Prioritise the visible range, then the buffer.
    int? maybeMissing;
    for (var i = firstVisible; i < lastVisible; i++) {
      if (!_cache.containsKey(i)) {
        maybeMissing = i;
        break;
      }
    }
    maybeMissing ??= _firstMissingInRange(windowStart, windowEnd);
    if (maybeMissing == null) return;
    final missingFrom = maybeMissing;

    _isFetching = true;
    final capturedKeyIndex = widget.keyIndex;
    final capturedDb = widget.selectedDatabase;

    try {
      final count =
          (windowEnd - missingFrom).clamp(1, _fetchBatchSize);

      final service = context.read<LmdbService>();
      final entries = await service.getEntryRange(
        capturedDb,
        capturedKeyIndex,
        missingFrom,
        count,
      );

      if (!mounted) return;
      // Ensure the database hasn't changed while we were awaiting.
      if (!identical(widget.keyIndex, capturedKeyIndex)) return;

      for (var i = 0; i < entries.length; i++) {
        _cache[missingFrom + i] = entries[i];
      }

      _evictDistant(firstVisible, lastVisible);
      setState(() {});
    } catch (e) {
      debugPrint('Failed to fetch entry range: $e');
    } finally {
      _isFetching = false;
    }

    // Check if there are still missing entries in the visible window and
    // schedule another fetch if needed.
    if (mounted && widget.searchQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchVisibleWindow();
      });
    }
  }

  int? _firstMissingInRange(int start, int end) {
    for (var i = start; i < end; i++) {
      if (!_cache.containsKey(i)) return i;
    }
    return null;
  }

  void _evictDistant(int firstVisible, int lastVisible) {
    if (_cache.length <= _maxCacheSize) return;
    final center = (firstVisible + lastVisible) ~/ 2;
    final sorted = _cache.keys.toList()
      ..sort((a, b) => (a - center).abs().compareTo((b - center).abs()));
    while (_cache.length > _maxCacheSize) {
      _cache.remove(sorted.removeLast());
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Total number of items to display.
  int get _totalCount {
    if (widget.searchQuery.isNotEmpty) {
      return widget.searchResults.length;
    }
    return widget.keyIndex.length;
  }

  String _buildStatusText() {
    if (widget.searchQuery.isNotEmpty) {
      return '${widget.searchResults.length} result(s)';
    }
    return '${widget.keyIndex.length} entries';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
          child: widget.isLoading && _totalCount == 0
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _totalCount == 0
                  ? const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No Entries',
                      subtitle: 'This database contains no entries.',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemExtent: _rowHeight,
                      itemCount: _totalCount,
                      itemBuilder: (context, index) {
                        if (widget.searchQuery.isNotEmpty) {
                          // Search mode: entries are pre-loaded.
                          return _EntryRow(
                            entry: widget.searchResults[index],
                            index: index,
                          );
                        }

                        // Browse mode: look up entry in the sparse cache.
                        final entry = _cache[index];
                        if (entry != null) {
                          return _EntryRow(entry: entry, index: index);
                        }

                        // Placeholder for not-yet-fetched entries.
                        return _PlaceholderRow(index: index);
                      },
                    ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row widgets
// ---------------------------------------------------------------------------

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

class _PlaceholderRow extends StatelessWidget {
  final int index;

  const _PlaceholderRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: index.isOdd
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
