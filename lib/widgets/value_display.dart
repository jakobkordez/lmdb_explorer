import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../bloc/entry_viewer/entry_viewer_state.dart';

/// Formats [bytes] according to the given [DisplayFormat].
class ValueDisplay extends StatelessWidget {
  final Uint8List bytes;
  final DisplayFormat format;
  final String label;
  final int hexWidth;

  const ValueDisplay({
    super.key,
    required this.bytes,
    required this.format,
    required this.label,
    this.hexWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatted = formatBytes(bytes, format, hexWidth: hexWidth);

    return SelectableText(
      formatted,
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'Consolas',
        color: colorScheme.onSurface,
        height: 1.5,
      ),
    );
  }

  /// Convert bytes to a string based on the display format.
  static String formatBytes(
    Uint8List bytes,
    DisplayFormat format, {
    int hexWidth = 8,
  }) {
    switch (format) {
      case DisplayFormat.utf8:
        try {
          return utf8.decode(bytes);
        } catch (_) {
          return '[Invalid UTF-8 -- ${bytes.length} bytes]\n'
              '${_toHexDump(bytes, bytesPerLine: hexWidth)}';
        }
      case DisplayFormat.hex:
        return _toHexDump(bytes, bytesPerLine: hexWidth);
      case DisplayFormat.base64:
        return base64Encode(bytes);
      case DisplayFormat.flatbuffers:
        return '[FlatBuffers view is only available in the value panel.]';
    }
  }

  /// Classic hex dump with offset, hex bytes, and ASCII.
  static String _toHexDump(Uint8List bytes, {int bytesPerLine = 8}) {
    if (bytes.isEmpty) return '(empty)';

    // The mid-line gap position (visual separator halfway through the hex).
    final midPoint = bytesPerLine ~/ 2;

    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i += bytesPerLine) {
      // Offset
      buffer.write(i.toRadixString(16).padLeft(8, '0'));
      buffer.write('  ');

      // Hex bytes
      for (var j = 0; j < bytesPerLine; j++) {
        if (i + j < bytes.length) {
          buffer.write(bytes[i + j].toRadixString(16).padLeft(2, '0'));
        } else {
          buffer.write('  ');
        }
        buffer.write(j == midPoint - 1 ? '  ' : ' ');
      }

      buffer.write(' |');

      // ASCII
      for (var j = 0; j < bytesPerLine && i + j < bytes.length; j++) {
        final b = bytes[i + j];
        buffer.write(b >= 32 && b <= 126 ? String.fromCharCode(b) : '.');
      }

      buffer.write('|');
      if (i + bytesPerLine < bytes.length) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Interpret bytes as integer values.
  static String _toIntegerDisplay(Uint8List bytes) {
    final lines = <String>[];
    final bd = ByteData.sublistView(bytes);

    if (bytes.isNotEmpty) {
      lines.add('uint8:  ${bytes[0]}');
      lines.add('int8:   ${bd.getInt8(0)}');
    }
    if (bytes.length >= 2) {
      lines.add('uint16 (LE): ${bd.getUint16(0, Endian.little)}');
      lines.add('uint16 (BE): ${bd.getUint16(0, Endian.big)}');
    }
    if (bytes.length >= 4) {
      lines.add('int32  (LE): ${bd.getInt32(0, Endian.little)}');
      lines.add('int32  (BE): ${bd.getInt32(0, Endian.big)}');
      lines.add('uint32 (LE): ${bd.getUint32(0, Endian.little)}');
      lines.add('float32(LE): ${bd.getFloat32(0, Endian.little)}');
    }
    if (bytes.length >= 8) {
      lines.add('int64  (LE): ${bd.getInt64(0, Endian.little)}');
      lines.add('int64  (BE): ${bd.getInt64(0, Endian.big)}');
      lines.add('float64(LE): ${bd.getFloat64(0, Endian.little)}');
    }
    if (bytes.isEmpty) {
      return '(empty)';
    }
    return lines.join('\n');
  }
}
