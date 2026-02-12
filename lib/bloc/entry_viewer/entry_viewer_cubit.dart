import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/database_entry.dart';
import 'entry_viewer_state.dart';

class EntryViewerCubit extends Cubit<EntryViewerState> {
  EntryViewerCubit() : super(const EntryViewerState());

  /// Select an entry to display in the detail panel.
  void selectEntry(DatabaseEntry entry) {
    emit(state.copyWith(selectedEntry: () => entry));
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
}
