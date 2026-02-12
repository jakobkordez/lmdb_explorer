import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Represents a single key-value entry from an LMDB database.
class DatabaseEntry extends Equatable {
  final Uint8List key;
  final Uint8List value;

  const DatabaseEntry({required this.key, required this.value});

  /// Attempt to decode [key] as a UTF-8 string.
  /// Returns null if the bytes are not valid UTF-8.
  String? get keyAsUtf8 {
    try {
      return utf8.decode(key);
    } catch (_) {
      return null;
    }
  }

  /// Attempt to decode [value] as a UTF-8 string.
  /// Returns null if the bytes are not valid UTF-8.
  String? get valueAsUtf8 {
    try {
      return utf8.decode(value);
    } catch (_) {
      return null;
    }
  }

  /// Key displayed as a hex string.
  String get keyAsHex => _bytesToHex(key);

  /// Value displayed as a hex string.
  String get valueAsHex => _bytesToHex(value);

  /// Value displayed as base64.
  String get valueAsBase64 => base64Encode(value);

  /// Key displayed as base64.
  String get keyAsBase64 => base64Encode(key);

  /// Best-effort display string for the key (UTF-8 if valid, hex otherwise).
  String get keyDisplay => keyAsUtf8 ?? keyAsHex;

  /// Truncated preview of the value for table display.
  String get valuePreview {
    final utf8Val = valueAsUtf8;
    if (utf8Val != null) {
      return utf8Val.length > 120 ? '${utf8Val.substring(0, 120)}...' : utf8Val;
    }
    final hex = valueAsHex;
    return hex.length > 120 ? '${hex.substring(0, 120)}...' : hex;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  @override
  List<Object?> get props => [key, value];
}
