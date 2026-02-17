import 'dart:io';
import 'dart:typed_data';

/// Service that shells out to the `flatc` FlatBuffers compiler to decode
/// FlatBuffers-encoded binary payloads into JSON.
class FlatcService {
  /// Decodes [bytes] using the given FlatBuffers [schemaPath] and optional
  /// [tableName], returning either JSON or a human-readable error message.
  ///
  /// The error messages are formatted similarly to the hex/flatbuffer views in
  /// the UI and include a hex dump of the raw bytes when decoding fails.
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
            '${details.isEmpty ? 'flatc returned exit code ${result.exitCode}' : details}';
      }

      if (!await jsonFile.exists()) {
        return '[FlatBuffers decode failed]\n'
            'flatc finished but did not produce payload.json.';
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

  /// Extracts the table names from a FlatBuffers schema file.
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
