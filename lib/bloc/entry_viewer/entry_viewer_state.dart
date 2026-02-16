import 'package:equatable/equatable.dart';

import '../../models/database_entry.dart';

/// How to display binary data in the detail panel.
enum DisplayFormat { utf8, hex, base64, flatbuffers }

class EntryViewerState extends Equatable {
  /// The currently selected entry, or null if nothing is selected.
  final DatabaseEntry? selectedEntry;

  /// The format used to display the key.
  final DisplayFormat keyFormat;

  /// The format used to display the value.
  final DisplayFormat valueFormat;

  /// Number of bytes per line in hex dump view (8 or 16).
  final int hexWidth;

  /// Optional path to the selected FlatBuffers schema (.fbs).
  final String? flatBuffersSchemaPath;

  /// Optional FlatBuffers table name used as root type for decoding.
  final String? flatBuffersTableName;

  const EntryViewerState({
    this.selectedEntry,
    this.keyFormat = DisplayFormat.utf8,
    this.valueFormat = DisplayFormat.utf8,
    this.hexWidth = 8,
    this.flatBuffersSchemaPath,
    this.flatBuffersTableName,
  });

  EntryViewerState copyWith({
    DatabaseEntry? Function()? selectedEntry,
    DisplayFormat? keyFormat,
    DisplayFormat? valueFormat,
    int? hexWidth,
    String? Function()? flatBuffersSchemaPath,
    String? Function()? flatBuffersTableName,
  }) {
    return EntryViewerState(
      selectedEntry: selectedEntry != null
          ? selectedEntry()
          : this.selectedEntry,
      keyFormat: keyFormat ?? this.keyFormat,
      valueFormat: valueFormat ?? this.valueFormat,
      hexWidth: hexWidth ?? this.hexWidth,
      flatBuffersSchemaPath: flatBuffersSchemaPath != null
          ? flatBuffersSchemaPath()
          : this.flatBuffersSchemaPath,
      flatBuffersTableName: flatBuffersTableName != null
          ? flatBuffersTableName()
          : this.flatBuffersTableName,
    );
  }

  @override
  List<Object?> get props => [
    selectedEntry,
    keyFormat,
    valueFormat,
    hexWidth,
    flatBuffersSchemaPath,
    flatBuffersTableName,
  ];
}
