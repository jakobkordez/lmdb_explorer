import 'package:equatable/equatable.dart';

import '../../models/database_entry.dart';

/// How to display binary data in the detail panel.
enum DisplayFormat { utf8, hex, base64, integer }

class EntryViewerState extends Equatable {
  /// The currently selected entry, or null if nothing is selected.
  final DatabaseEntry? selectedEntry;

  /// The format used to display the key.
  final DisplayFormat keyFormat;

  /// The format used to display the value.
  final DisplayFormat valueFormat;

  /// Number of bytes per line in hex dump view (8 or 16).
  final int hexWidth;

  const EntryViewerState({
    this.selectedEntry,
    this.keyFormat = DisplayFormat.utf8,
    this.valueFormat = DisplayFormat.utf8,
    this.hexWidth = 8,
  });

  EntryViewerState copyWith({
    DatabaseEntry? Function()? selectedEntry,
    DisplayFormat? keyFormat,
    DisplayFormat? valueFormat,
    int? hexWidth,
  }) {
    return EntryViewerState(
      selectedEntry: selectedEntry != null
          ? selectedEntry()
          : this.selectedEntry,
      keyFormat: keyFormat ?? this.keyFormat,
      valueFormat: valueFormat ?? this.valueFormat,
      hexWidth: hexWidth ?? this.hexWidth,
    );
  }

  @override
  List<Object?> get props => [selectedEntry, keyFormat, valueFormat, hexWidth];
}
