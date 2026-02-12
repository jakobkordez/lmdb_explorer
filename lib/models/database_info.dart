import 'package:equatable/equatable.dart';

/// Holds metadata and statistics about an LMDB named database.
class DatabaseInfo extends Equatable {
  /// The name of the database, or null for the default (unnamed) database.
  final String? name;

  /// Number of entries in this database.
  final int entries;

  /// Page size in bytes.
  final int pageSize;

  /// Depth of the B+ tree.
  final int depth;

  /// Number of branch pages.
  final int branchPages;

  /// Number of leaf pages.
  final int leafPages;

  /// Number of overflow pages.
  final int overflowPages;

  const DatabaseInfo({
    required this.name,
    required this.entries,
    required this.pageSize,
    required this.depth,
    required this.branchPages,
    required this.leafPages,
    required this.overflowPages,
  });

  /// A human-readable display name.
  String get displayName => name ?? '(default)';

  /// Estimated data size in bytes.
  int get estimatedSize => (leafPages + branchPages + overflowPages) * pageSize;

  @override
  List<Object?> get props => [
    name,
    entries,
    pageSize,
    depth,
    branchPages,
    leafPages,
    overflowPages,
  ];
}
