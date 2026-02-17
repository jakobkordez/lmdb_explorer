<h1 align="center" style="text-align: center; display: flex; align-items: center; justify-content: center; gap: 16px;">
  <img src="assets/app_icon.png" alt="LMDB Explorer" width="92" height="92">
  <span>LMDB Explorer</span>
</h1>

A desktop Flutter application for browsing and inspecting [LMDB](https://www.symas.com/lmdb) (Lightning Memory-Mapped Database) environments. Opens databases in **read-only** mode -- no risk of accidental writes.

### [Download here](https://github.com/jakobkordez/lmdb_explorer/releases/latest)

## Features

- **Open any LMDB environment** via native directory picker
- **Browse named databases** listed in a sidebar
- **Search** entries by key (case-insensitive substring match)
- **Multi-format value viewer** -- switch between UTF-8, hex dump, Base64, and flatbuffers interpretations
- **Copy to clipboard** for both keys and values
- **Database statistics** -- page size, B+ tree depth, branch/leaf/overflow pages, entry count, and estimated size

## Getting Started

### Setup

```bash
# Clone and enter the project
cd lmdb_explorer

# Install dependencies
flutter pub get

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
