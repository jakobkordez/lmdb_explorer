import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/flatc_service.dart';

class FlatBuffersValueDisplay extends StatefulWidget {
  final Uint8List bytes;
  final String? schemaPath;
  final String? tableName;

  const FlatBuffersValueDisplay({
    super.key,
    required this.bytes,
    required this.schemaPath,
    required this.tableName,
  });

  @override
  State<FlatBuffersValueDisplay> createState() =>
      _FlatBuffersValueDisplayState();
}

class _FlatBuffersValueDisplayState extends State<FlatBuffersValueDisplay> {
  late Future<String> _decodedFuture;

  @override
  void initState() {
    super.initState();
    _decodedFuture = FlatcService.decode(
      widget.bytes,
      schemaPath: widget.schemaPath,
      tableName: widget.tableName,
    );
  }

  @override
  void didUpdateWidget(covariant FlatBuffersValueDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schemaPath != oldWidget.schemaPath ||
        widget.tableName != oldWidget.tableName ||
        !listEquals(widget.bytes, oldWidget.bytes)) {
      _decodedFuture = FlatcService.decode(
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

class FlatBuffersTableDropdown extends StatefulWidget {
  final String schemaPath;
  final String? value;
  final ValueChanged<String?> onChanged;

  const FlatBuffersTableDropdown({
    super.key,
    required this.schemaPath,
    required this.value,
    required this.onChanged,
  });

  @override
  State<FlatBuffersTableDropdown> createState() =>
      _FlatBuffersTableDropdownState();
}

class _FlatBuffersTableDropdownState extends State<FlatBuffersTableDropdown> {
  late Future<List<String>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _tablesFuture = FlatcService.extractTableNames(widget.schemaPath);
  }

  @override
  void didUpdateWidget(covariant FlatBuffersTableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schemaPath != widget.schemaPath) {
      _tablesFuture = FlatcService.extractTableNames(widget.schemaPath);
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
              borderRadius: BorderRadius.circular(8),
              isDense: true,
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
    return Container(decoration: _outlinedDecoration(context), child: content);
  }
}
