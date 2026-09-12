# Clavis Shell

> [!NOTE]
> Clavis is under active development.

A desktop shell for [niri](https://github.com/YaLTeR/niri), built with [Quickshell](https://quickshell.org/), QML, Qt 6 and native C++ modules.

<table>
  <tr>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-20-21.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-20-21.png" alt="Clavis Shell screenshot 1" width="100%" /></a></td>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-23-30.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-23-30.png" alt="Clavis Shell screenshot 2" width="100%" /></a></td>
  </tr>
  <tr>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-32-08.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-32-08.png" alt="Clavis Shell screenshot 3" width="100%" /></a></td>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-33-40.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-33-40.png" alt="Clavis Shell screenshot 4" width="100%" /></a></td>
  </tr>
  <tr>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-43-18.png"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/Screenshot%20from%202026-09-12%2015-43-18.png" alt="Clavis Shell screenshot 5" width="100%" /></a></td>
    <td width="50%"><a href="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_15-36-29_194021.gif"><img src="https://raw.githubusercontent.com/StatIndet/picture/main/clavis-shell/recording_20260912_15-36-29_194021.gif" alt="Clavis Shell animation" width="100%" /></a></td>
  </tr>
</table>

## Highlights

- Keystone and edge bars
- Independently positioned information and quick-settings sidebars; same-side panels switch automatically
- Spotlight-style app, wallpaper, clipboard and web search
- Wallpaper transitions and niri-aware parallax
- Weather, weather maps and animated conditions
- Draggable system cards with fine-grid placement in the drawer and on the desktop
- MPRIS media controls and synchronized lyrics
- Screen and audio recording controls
- Dynamic Material theming with Matugen
- Settings center for shell, cursor, wallpaper, default apps and integrations
- Native QML modules for niri, media, weather, Cava, shortcut recording

## Project family

Clavis is split into three repositories:

| Project | Role |
| --- | --- |
| **[Clavis Shell](https://github.com/StatIndet/quickshell)** | Quickshell UI, reactive services and native QML modules |
| **[key-cli](https://github.com/StatIndet/key-cli)** | `key` command, shell IPC/lifecycle, recording and clipboard integration |
| **[keytop](https://github.com/StatIndet/keytop)** | Kernel/system information snapshots and JSONL metrics for Clavis; secondary TUI |

Install `key-cli` and `keytop` for the full Clavis experience. For key-cli development,
use its editable `.venv`; for a standalone source installation, use its
`scripts/install.sh`. Distribution packaging is not required. See
[development integration](docs/development.md#与-key-cli-源码联调) for service overrides.

Clavis consumes `keytop value stream --format jsonl` directly. Metrics collection and
parsing belong to keytop; recording, clipboard and keyboard-state backends belong to
key-cli. Each repository builds and tests independently.

## Requirements

Core development dependencies include:

- Quickshell
- Qt 6
- CMake
- Ninja
- QtKeychain
- MapLibre Native Qt (`maplibre-native-qt` on Arch Linux)
- PipeWire
- libudev (`systemd-libs` on Arch Linux)
- libcava
- M3Shapes QML runtime module (`qt6-m3shapes-git` on Arch Linux)

Some features also use external tools such as Matugen, awww, cliphist, wl-clipboard, gpu-screen-recorder and FFmpeg.

## Development

From the checkout, configure and build the native QML modules:

```bash
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug

cmake --build build
```

Make the checkout available as the `clavis` Quickshell configuration. If an entry
already exists at this path, inspect it before replacing it:

```bash
mkdir -p ~/.config/quickshell
ln -sT "$PWD" ~/.config/quickshell/clavis
```

Run the source shell with the build-tree QML modules:

```bash
MALLOC_CONF="${MALLOC_CONF-thp:never,narenas:4,dirty_decay_ms:3000}" \
QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  key shell
```

QML changes can be reloaded directly. Rebuild after changing native C++ modules.
The allocator settings above match the supplied user service and are ignored by
Quickshell builds without jemalloc. See [development details](docs/development.md)
for entry points and service integration.

The native QML modules are written to `build/qml/` by CMake. `qs.*` imports are
Quickshell root-relative modules; `Clavis.*` imports are native modules generated by
`qt_add_qml_module()`. `import M3Shapes` resolves the separately installed system
module through Qt’s normal import paths; Clavis does not build or install it.

## System install

```bash
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/

cmake --build build
sudo cmake --install build
```

Start Clavis with:

```bash
key shell
```

## Configuration

Most options are available from the Clavis settings center, including English,
Simplified Chinese and Traditional Chinese interface languages.

**General → Sidebars** controls the information sidebar (notifications, drawer and
weather) and the quick-settings sidebar independently. Different-side panels can stay
open together. On the same side, opening one closes the other before showing the new
panel. The optional keep-loaded setting retains content after its first use.

New shortcuts can call Quickshell directly:

```bash
qs -c clavis ipc call sidebar toggle dashboard
qs -c clavis ipc call sidebar toggle quicksettings
qs -c clavis ipc call shortcut-map toggle
```

The legacy sidebar arguments `left` and `right` remain content aliases, even when
positions change. See [IPC and default shortcuts](docs/ipc.md).

User configuration and state follow XDG paths, with the main shell configuration stored under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/clavis/
```

Clavis-managed niri fragments are written under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/niri/clavis/
```

## Dynamic theming

Clavis uses [Matugen](https://github.com/InioX/matugen) to generate Material color schemes from the current wallpaper or a source color.

The settings center can generate themes for supported applications including btop, Cava, Kitty and Yazi.

## Development checks

```bash
scripts/dev/check.sh          # changed files; native build/tests only when affected
scripts/dev/check.sh --native # force native build and CTest
scripts/dev/check.sh --full   # explicit whole-tree lint, build and CTest
```

Use one appropriate command, not all three. When editing QML, run
`scripts/dev/format-qml.sh` before checking. Qt 6 tools are selected explicitly;
normal formatting and linting cover changed files only. For shared QML interface
changes, include the affected consumers; use `--full` when that scope cannot be
reliably bounded. A native build is also needed on a fresh
checkout before QML tooling can resolve native imports.

See [development checks](docs/development-checks.md) for scope, dependencies,
known environment failures and diagnostic logs. Whole-tree QML formatting is an
explicit migration, never part of routine checks.

## Acknowledgements

Clavis takes inspiration from and integrates ideas or components from projects including:

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- [Zen Browser](https://github.com/zen-browser/desktop) — palette algorithms and editor; see [source and license mapping](licenses/README.md).
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)
- [qml-niri](https://github.com/imiric/qml-niri)
- [Breezy Weather](https://github.com/breezy-weather/breezy-weather)
- [m3shapes](https://github.com/soramanew/m3shapes)
- [HyDE](https://github.com/HyDE-Project/HyDE)

Third-party license notices are kept in [`licenses/`](licenses/).


## Arch packages and date releases

Arch x86_64 packaging and GitHub Actions release workflows are included. Versions use
`2026.9.12` (tag `v2026.9.12`), with `.1`, `.2` for further releases on the same day.
See [GitHub release setup](docs/releasing.md) and the
[dependency inventory](docs/dependencies.md). Each repository remains independently buildable.

The [Arch one-command installer](docs/installation.md) installs the full dependency profile
and asks separately about keyboard access, keytop capabilities and Niri user services.

## License

See [LICENSE](LICENSE).
