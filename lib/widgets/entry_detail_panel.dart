import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/entry_viewer/entry_viewer_state.dart';
import 'empty_state.dart';
import 'value_display.dart';

class EntryDetailPanel extends StatelessWidget {
  const EntryDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryViewerCubit, EntryViewerState>(
      builder: (context, state) {
        if (state.selectedEntry == null) {
          return const EmptyState(
            icon: Icons.touch_app_outlined,
            title: 'No Entry Selected',
            subtitle: 'Select an entry from the table to view details.',
          );
        }
        return _DetailContent(state: state);
      },
    );
  }
}

class _DetailContent extends StatelessWidget {
  final EntryViewerState state;

  const _DetailContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final entry = state.selectedEntry!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Entry Detail',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${entry.key.length} + ${entry.value.length} bytes',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Key section
              _SectionHeader(
                label: 'Key',
                size: entry.key.length,
                selectedFormat: state.keyFormat,
                onFormatChanged: (fmt) {
                  context.read<EntryViewerCubit>().setKeyFormat(fmt);
                },
                onCopy: () => _copyToClipboard(
                  context,
                  ValueDisplay.formatBytes(entry.key, state.keyFormat),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ValueDisplay(
                  bytes: entry.key,
                  format: state.keyFormat,
                  label: 'Key',
                ),
              ),
              const SizedBox(height: 20),
              // Value section
              _SectionHeader(
                label: 'Value',
                size: entry.value.length,
                selectedFormat: state.valueFormat,
                onFormatChanged: (fmt) {
                  context.read<EntryViewerCubit>().setValueFormat(fmt);
                },
                onCopy: () => _copyToClipboard(
                  context,
                  ValueDisplay.formatBytes(entry.value, state.valueFormat),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ValueDisplay(
                  bytes: entry.value,
                  format: state.valueFormat,
                  label: 'Value',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int size;
  final DisplayFormat selectedFormat;
  final ValueChanged<DisplayFormat> onFormatChanged;
  final VoidCallback onCopy;

  const _SectionHeader({
    required this.label,
    required this.size,
    required this.selectedFormat,
    required this.onFormatChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Text(
          '($size bytes)',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        // Format toggle buttons
        SizedBox(
          height: 28,
          child: SegmentedButton<DisplayFormat>(
            segments: const [
              ButtonSegment(value: DisplayFormat.utf8, label: Text('UTF-8')),
              ButtonSegment(value: DisplayFormat.hex, label: Text('Hex')),
              ButtonSegment(value: DisplayFormat.base64, label: Text('B64')),
              ButtonSegment(value: DisplayFormat.integer, label: Text('Int')),
            ],
            selected: {selectedFormat},
            onSelectionChanged: (set) => onFormatChanged(set.first),
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          width: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: const Icon(Icons.copy),
            tooltip: 'Copy $label',
            onPressed: onCopy,
          ),
        ),
      ],
    );
  }
}
