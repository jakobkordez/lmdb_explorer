# LMDB Explorer

A desktop Flutter application for browsing and inspecting [LMDB](https://www.symas.com/lmdb) (Lightning Memory-Mapped Database) environments. Opens databases in **read-only** mode -- no risk of accidental writes.

## Features

- **Open any LMDB environment** via native directory picker
- **Browse named databases** listed in a sidebar
- **Paginated entry table** with lazy-scroll loading for large datasets
- **Search** entries by key (case-insensitive substring match)
- **Multi-format value viewer** -- switch between UTF-8, hex dump, Base64, and integer interpretations
- **Copy to clipboard** for both keys and values
- **Database statistics** -- page size, B+ tree depth, branch/leaf/overflow pages, entry count, and estimated size
- **Dark and light theme** following system preference (Material 3)

## Getting Started

### Setup

```bash
# Clone and enter the project
cd lmdb_explorer

# Install dependencies
flutter pub get

# Download the native LMDB library (lmdb.dll / liblmdb.so)
dart run dart_lmdb2:fetch_native

# Run the app
flutter run
```

### Build a release

```bash
# Windows
flutter build windows

# Linux
flutter build linux
```

The built executable will be in `build/<platform>/x64/runner/Release/`.
