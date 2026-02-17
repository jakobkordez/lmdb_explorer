import 'package:flutter/material.dart';

import '../bloc/entry_viewer/entry_viewer_state.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  final int size;
  final DisplayFormat selectedFormat;
  final ValueChanged<DisplayFormat> onFormatChanged;
  final VoidCallback onCopy;
  final bool isValidUtf8;
  final bool allowFlatBuffers;
  final String? schemaPath;
  final Widget? tableSelector;
  final int hexWidth;
  final ValueChanged<int>? onHexWidthChanged;
  final Future<void> Function()? onPickSchema;
  final VoidCallback? onClearSchema;

  const SectionHeader({
    super.key,
    required this.label,
    required this.size,
    required this.selectedFormat,
    required this.onFormatChanged,
    required this.onCopy,
    required this.isValidUtf8,
    this.allowFlatBuffers = false,
    this.schemaPath,
    this.tableSelector,
    required this.hexWidth,
    this.onHexWidthChanged,
    this.onPickSchema,
    this.onClearSchema,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final segments = <ButtonSegment<DisplayFormat>>[
      ButtonSegment(
        value: DisplayFormat.utf8,
        label: const Text('UTF-8'),
        enabled: isValidUtf8,
      ),
      const ButtonSegment(value: DisplayFormat.hex, label: Text('Hex')),
      const ButtonSegment(value: DisplayFormat.base64, label: Text('B64')),
      if (allowFlatBuffers)
        const ButtonSegment(
          value: DisplayFormat.flatbuffers,
          label: Text('FlatBuffers'),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($size bytes)',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
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
        ),
        const SizedBox(height: 6),
        // Format toggle buttons
        SegmentedButton<DisplayFormat>(
          showSelectedIcon: false,
          segments: segments,
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
        if (onHexWidthChanged != null &&
            selectedFormat == DisplayFormat.hex) ...[
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 8, label: Text('8')),
              ButtonSegment(value: 16, label: Text('16')),
            ],
            selected: {hexWidth},
            onSelectionChanged: (set) => onHexWidthChanged!(set.first),
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
        ],
        if (allowFlatBuffers &&
            selectedFormat == DisplayFormat.flatbuffers &&
            (onPickSchema != null || tableSelector != null)) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Schema: label + pick/clear
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Schema',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InputChip(
                    label: Text(
                      schemaPath
                              ?.replaceAll(RegExp(r'[/\\]'), '/')
                              .split('/')
                              .last ??
                          'Select…',
                      style: textTheme.labelSmall,
                    ),
                    onPressed: schemaPath == null ? onPickSchema : null,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: onClearSchema,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ],
              ),
              if (tableSelector != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Root type',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    tableSelector!,
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

