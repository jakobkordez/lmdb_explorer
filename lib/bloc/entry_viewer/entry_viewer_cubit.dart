import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/database_entry.dart';
import 'entry_viewer_state.dart';

class EntryViewerCubit extends Cubit<EntryViewerState> {
  EntryViewerCubit() : super(const EntryViewerState());

  /// Select an entry to display in the detail panel.
  /// Automatically switches to hex if the current format is UTF-8 but the
  /// bytes are not valid UTF-8.
  void selectEntry(DatabaseEntry entry) {
    final keyFormat =
        state.keyFormat == DisplayFormat.utf8 && entry.keyAsUtf8 == null
        ? DisplayFormat.hex
        : state.keyFormat;
    final valueFormat =
        state.valueFormat == DisplayFormat.utf8 && entry.valueAsUtf8 == null
        ? DisplayFormat.hex
        : state.valueFormat;

    emit(
      state.copyWith(
        selectedEntry: () => entry,
        keyFormat: keyFormat,
        valueFormat: valueFormat,
      ),
    );
  }

  /// Clear the selected entry.
  void clearSelection() {
    emit(state.copyWith(selectedEntry: () => null));
  }

  /// Change how the key bytes are displayed.
  void setKeyFormat(DisplayFormat format) {
    emit(state.copyWith(keyFormat: format));
  }

  /// Change how the value bytes are displayed.
  void setValueFormat(DisplayFormat format) {
    emit(state.copyWith(valueFormat: format));
  }

  /// Change the hex dump width (8 or 16 bytes per line).
  void setHexWidth(int width) {
    assert(width == 8 || width == 16);
    emit(state.copyWith(hexWidth: width));
  }
}
