import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lmdb_explorer/services/flatc_service.dart';

import '../bloc/entry_viewer/entry_viewer_cubit.dart';
import '../bloc/entry_viewer/entry_viewer_state.dart';
import 'empty_state.dart';
import 'value_display.dart';
import 'entry_section_header.dart';
import 'flatbuffers_value_display.dart';
import 'value_container.dart';

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
              SectionHeader(
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
              ValueContainer(
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
              SectionHeader(
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
                    ? FlatBuffersTableDropdown(
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
              ValueContainer(
                colorScheme: colorScheme,
                enableHorizontalScroll:
                    state.valueFormat != DisplayFormat.base64 &&
                    state.valueFormat != DisplayFormat.flatbuffers,
                child: state.valueFormat == DisplayFormat.flatbuffers
                    ? FlatBuffersValueDisplay(
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
        ? await FlatcService.decode(
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
