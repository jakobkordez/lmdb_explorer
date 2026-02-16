import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
                isValidUtf8: entry.keyAsUtf8 != null,
                hexWidth: state.hexWidth,
                onHexWidthChanged: (w) =>
                    context.read<EntryViewerCubit>().setHexWidth(w),
                onFormatChanged: (fmt) {
                  context.read<EntryViewerCubit>().setKeyFormat(fmt);
                },
                onCopy: () => _copyToClipboard(
                  context,
                  ValueDisplay.formatBytes(
                    entry.key,
                    state.keyFormat,
                    hexWidth: state.hexWidth,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _ValueContainer(
                colorScheme: colorScheme,
                enableHorizontalScroll: state.keyFormat != DisplayFormat.base64,
                child: ValueDisplay(
                  bytes: entry.key,
                  format: state.keyFormat,
                  label: 'Key',
                  hexWidth: state.hexWidth,
                ),
              ),
              const SizedBox(height: 20),
              // Value section
              _SectionHeader(
                label: 'Value',
                size: entry.value.length,
                selectedFormat: state.valueFormat,
                isValidUtf8: entry.valueAsUtf8 != null,
                allowFlatBuffers: true,
                schemaPath: state.flatBuffersSchemaPath,
                hexWidth: state.hexWidth,
                onHexWidthChanged: (w) =>
                    context.read<EntryViewerCubit>().setHexWidth(w),
                onPickSchema: () => _pickFlatBuffersSchema(context),
                onClearSchema: state.flatBuffersSchemaPath == null
                    ? null
                    : () {
                        context
                            .read<EntryViewerCubit>()
                            .setFlatBuffersSchemaPath(null);
                        context
                            .read<EntryViewerCubit>()
                            .setFlatBuffersTableName(null);
                      },
                tableSelector: state.flatBuffersSchemaPath != null
                    ? _FlatBuffersTableDropdown(
                        schemaPath: state.flatBuffersSchemaPath!,
                        value: state.flatBuffersTableName,
                        onChanged: (v) => context
                            .read<EntryViewerCubit>()
                            .setFlatBuffersTableName(v),
                      )
                    : null,
                onFormatChanged: (fmt) {
                  context.read<EntryViewerCubit>().setValueFormat(fmt);
                },
                onCopy: () {
                  _copyValueToClipboard(context, state, entry.value);
                },
              ),
              const SizedBox(height: 6),
              _ValueContainer(
                colorScheme: colorScheme,
                enableHorizontalScroll:
                    state.valueFormat != DisplayFormat.base64 &&
                    state.valueFormat != DisplayFormat.flatbuffers,
                child: state.valueFormat == DisplayFormat.flatbuffers
                    ? _FlatBuffersValueDisplay(
                        bytes: entry.value,
                        schemaPath: state.flatBuffersSchemaPath,
                        tableName: state.flatBuffersTableName,
                      )
                    : ValueDisplay(
                        bytes: entry.value,
                        format: state.valueFormat,
                        label: 'Value',
                        hexWidth: state.hexWidth,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFlatBuffersSchema(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FlatBuffers Schema (.fbs)',
      type: FileType.custom,
      allowedExtensions: const ['fbs'],
    );
    if (!context.mounted || result == null) return;

    final schemaPath = result.files.single.path;
    if (schemaPath == null || schemaPath.isEmpty) return;

    context.read<EntryViewerCubit>().setFlatBuffersSchemaPath(schemaPath);
    context.read<EntryViewerCubit>().setFlatBuffersTableName(null);
  }

  Future<void> _copyValueToClipboard(
    BuildContext context,
    EntryViewerState state,
    Uint8List value,
  ) async {
    final text = state.valueFormat == DisplayFormat.flatbuffers
        ? await _FlatBuffersDecoder.decode(
            value,
            schemaPath: state.flatBuffersSchemaPath,
            tableName: state.flatBuffersTableName,
            hexWidth: state.hexWidth,
          )
        : ValueDisplay.formatBytes(
            value,
            state.valueFormat,
            hexWidth: state.hexWidth,
          );

    if (!context.mounted) return;
    _copyToClipboard(context, text);
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

class _ValueContainer extends StatefulWidget {
  final ColorScheme colorScheme;
  final Widget child;
  final bool enableHorizontalScroll;

  const _ValueContainer({
    required this.colorScheme,
    required this.child,
    this.enableHorizontalScroll = true,
  });

  @override
  State<_ValueContainer> createState() => _ValueContainerState();
}

class _ValueContainerState extends State<_ValueContainer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: widget.enableHorizontalScroll
          ? Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: widget.child,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: widget.child,
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
  final bool isValidUtf8;
  final bool allowFlatBuffers;
  final String? schemaPath;
  final Widget? tableSelector;
  final int hexWidth;
  final ValueChanged<int>? onHexWidthChanged;
  final Future<void> Function()? onPickSchema;
  final VoidCallback? onClearSchema;

  const _SectionHeader({
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
        SizedBox(
          height: 28,
          child: SegmentedButton<DisplayFormat>(
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
        ),
        if (onHexWidthChanged != null &&
            selectedFormat == DisplayFormat.hex) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: SegmentedButton<int>(
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
                  if (schemaPath == null)
                    Tooltip(
                      message: 'Select FlatBuffers schema (.fbs)',
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: onPickSchema,
                          icon: Icon(
                            Icons.schema_outlined,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          label: Text('Select…', style: textTheme.labelSmall),
                        ),
                      ),
                    )
                  else
                    InputChip(
                      label: Text(
                        schemaPath!
                            .replaceAll(RegExp(r'[/\\]'), '/')
                            .split('/')
                            .last,
                        style: textTheme.labelSmall,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: onClearSchema,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
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

class _FlatBuffersValueDisplay extends StatefulWidget {
  final Uint8List bytes;
  final String? schemaPath;
  final String? tableName;

  const _FlatBuffersValueDisplay({
    required this.bytes,
    required this.schemaPath,
    required this.tableName,
  });

  @override
  State<_FlatBuffersValueDisplay> createState() =>
      _FlatBuffersValueDisplayState();
}

class _FlatBuffersValueDisplayState extends State<_FlatBuffersValueDisplay> {
  late Future<String> _decodedFuture;

  @override
  void initState() {
    super.initState();
    _decodedFuture = _FlatBuffersDecoder.decode(
      widget.bytes,
      schemaPath: widget.schemaPath,
      tableName: widget.tableName,
    );
  }

  @override
  void didUpdateWidget(covariant _FlatBuffersValueDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schemaPath != oldWidget.schemaPath ||
        widget.tableName != oldWidget.tableName ||
        !listEquals(widget.bytes, oldWidget.bytes)) {
      _decodedFuture = _FlatBuffersDecoder.decode(
        widget.bytes,
        schemaPath: widget.schemaPath,
        tableName: widget.tableName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<String>(
      future: _decodedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Decoding FlatBuffers...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        return SelectableText(
          snapshot.data ?? '',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Consolas',
            color: colorScheme.onSurface,
            height: 1.5,
          ),
        );
      },
    );
  }
}

class _FlatBuffersTableDropdown extends StatefulWidget {
  final String schemaPath;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FlatBuffersTableDropdown({
    required this.schemaPath,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_FlatBuffersTableDropdown> createState() =>
      _FlatBuffersTableDropdownState();
}

class _FlatBuffersTableDropdownState extends State<_FlatBuffersTableDropdown> {
  late Future<List<String>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _tablesFuture = _FlatBuffersDecoder.extractTableNames(widget.schemaPath);
  }

  @override
  void didUpdateWidget(covariant _FlatBuffersTableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schemaPath != widget.schemaPath) {
      _tablesFuture = _FlatBuffersDecoder.extractTableNames(widget.schemaPath);
    }
  }

  static BoxDecoration _outlinedDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = FutureBuilder<List<String>>(
      future: _tablesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.connectionState == ConnectionState.waiting
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Loading…', style: theme.textTheme.labelSmall),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'No tables',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
        }
        final tables = snapshot.data!;
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: widget.value != null && widget.value!.isNotEmpty
                  ? widget.value
                  : null,
              isExpanded: true,
              hint: Text('—', style: theme.textTheme.labelSmall),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—', style: TextStyle(fontSize: 12)),
                ),
                ...tables.map(
                  (t) => DropdownMenuItem<String?>(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              onChanged: (v) => widget.onChanged(v),
              style: theme.textTheme.labelSmall,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        );
      },
    );
    return SizedBox(
      height: 28,
      child: Container(
        decoration: _outlinedDecoration(context),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        alignment: Alignment.centerLeft,
        child: content,
      ),
    );
  }
}

class _FlatBuffersDecoder {
  static Future<String> decode(
    Uint8List bytes, {
    required String? schemaPath,
    required String? tableName,
    int hexWidth = 8,
  }) async {
    if (schemaPath == null || schemaPath.isEmpty) {
      return '[FlatBuffers schema not selected]\n'
          'Select a .fbs file to decode this value.';
    }

    final schemaFile = File(schemaPath);
    if (!await schemaFile.exists()) {
      return '[FlatBuffers schema not found]\n$schemaPath';
    }

    final tempDir = await Directory.systemTemp.createTemp('lmdb_fb_');
    final binFile = File('${tempDir.path}${Platform.pathSeparator}payload.bin');
    final jsonFile = File(
      '${tempDir.path}${Platform.pathSeparator}payload.json',
    );

    try {
      await binFile.writeAsBytes(bytes, flush: true);

      final executable = Platform.isWindows ? 'flatc.exe' : 'flatc';
      final args = <String>[
        '--raw-binary',
        '--strict-json',
        '--defaults-json',
        '-t',
        if (tableName != null && tableName.isNotEmpty) ...[
          '--root-type',
          tableName,
        ],
        '-o',
        tempDir.path,
        schemaPath,
        '--',
        binFile.path,
      ];
      final result = await Process.run(executable, args);

      if (result.exitCode != 0) {
        final stderrText = (result.stderr ?? '').toString().trim();
        final stdoutText = (result.stdout ?? '').toString().trim();
        final details = stderrText.isNotEmpty ? stderrText : stdoutText;
        return '[FlatBuffers decode failed]\n'
            '${details.isEmpty ? 'flatc returned exit code ${result.exitCode}' : details}\n\n'
            'Raw hex:\n${ValueDisplay.formatBytes(bytes, DisplayFormat.hex, hexWidth: hexWidth)}';
      }

      if (!await jsonFile.exists()) {
        return '[FlatBuffers decode failed]\n'
            'flatc finished but did not produce payload.json.\n\n'
            'Raw hex:\n${ValueDisplay.formatBytes(bytes, DisplayFormat.hex, hexWidth: hexWidth)}';
      }

      return await jsonFile.readAsString();
    } on ProcessException catch (e) {
      return '[flatc executable not found]\n'
          '${e.message}\n\n'
          'Install FlatBuffers compiler and make sure flatc is available in PATH.';
    } catch (e) {
      return '[FlatBuffers decode error]\n$e';
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<List<String>> extractTableNames(String schemaPath) async {
    final schemaFile = File(schemaPath);
    if (!await schemaFile.exists()) return const [];

    final content = await schemaFile.readAsString();
    final matches = RegExp(
      r'^\s*table\s+([A-Za-z_][A-Za-z0-9_]*)\b',
      multiLine: true,
    ).allMatches(content);
    return matches.map((m) => m.group(1)!).toSet().toList()..sort();
  }
}
