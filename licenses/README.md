# Third-party sources

Existing license files in this directory continue to cover their respective
components.

## Zen Browser

Source: [Zen Browser / zen-browser/desktop](https://github.com/zen-browser/desktop),
local checkout commit `412731f37e567223097101d9fae9f9d364708b6b`.

| Upstream file | Clavis adaptation |
| --- | --- |
| `src/zen/spaces/ZenGradientGenerator.mjs` | `Common/functions/ZenPalette.js`: color-position math, harmony relations, primary identity and Linux opaque background semantics; `assets/shaders/zen-palette.frag`: layered gradients |
| `src/browser/base/content/zen-panels/theme-picker.inc` | `Common/functions/ZenPalette.js`: all 41 presets across five pages, including positions, algorithms, lightness and type; `Modules/ControlCenter/ZenPaletteEditor.qml`: editor controls |
| `src/zen/spaces/zen-gradient-generator.css` | `Modules/ControlCenter/ZenPaletteEditor.qml`: dotted editing pad, primary/secondary dots, preset pagination, opacity range and 16-position grain control |
| `src/zen/common/styles/zen-browser-ui.css` | `assets/shaders/zen-palette.frag` and `Modules/Wallpaper/ZenPaletteRenderer.qml`: screen-blended background layers and ordinary alpha grain overlay |

These files retain the upstream MPL notice. The complete license is in
`ZenBrowser-MPL-2.0.txt`. No file-level “Incompatible With Secondary Licenses”
notice was found in the adapted sources. Exhibit B in the full license is a
notice template, not such a designation of these files. No separate license
was found for these source files. No Zen artwork, logos, or grain bitmap is
copied; the shader implements independent, deterministic monochrome grain.

The modified files and their additions are initially distributed under both
MPL-2.0 and GPL-3.0-or-later as part of the Clavis Larger Work, pursuant to MPL
section 3.3. Recipients may use these files under either license. See Mozilla's
[MPL-in-GPL developer guidelines](https://www.mozilla.org/en-US/MPL/2.0/combining-mpl-and-gpl/).
The existing GPL code is reused through component interfaces, not copied into
the MPL files. Clavis configuration, draft lifecycle and backend services remain
under the project's original license.

Adaptations replace browser DOM/events with QML, normalize editor positions on a fixed 380px square color plane (the upstream
nominal panel width), independent of browser padding and live QML geometry,
make secondary positions and RGB derived state, fix secondary dragging and
primary selection, canonicalize the upstream `float` preset spelling to
`floating`, and keep theme selection local to the wallpaper. The desktop uses
an opaque base following the global Clavis theme, using Zen’s light/dark base
colors instead of browser platform transparency. Palette data and presets do not
select or change the global theme.
Save/cancel, per-output scopes and external theme generation belong to Clavis.

QML/JS and GLSL source are installed with the shell. The shader is compiled by
`qt_add_shaders` in `core/plugin/runtime/CMakeLists.txt` into the existing
`Clavis.Runtime` module at `qrc:/clavis/shaders/zen-palette.frag.qsb`; normal
CMake source distributions include that build recipe. No reference checkout
is needed to build, test, install or run Clavis. This port does not imply Zen
Browser endorsement.

## M3Shapes and Cookie Clock

[M3Shapes](https://github.com/soramanew/m3shapes) is an external QML runtime
dependency, supplied on Arch by `qt6-m3shapes-git`. Clavis no longer distributes
or builds its former vendored C++ geometry, morphing, renderer or plugin sources.
`M3Shapes-Apache-2.0.txt` is retained as an upstream license reference; the installed
module and its license are provided by the system package.

The retained `Modules/SystemCards/CookieClock/` QML geometry and presentation
adaptations from end-4/dots-hyprland remain covered by
`end-4-dots-hyprland-GPL-3.0.txt` and their source notices. They consume the external
M3Shapes API and are not the removed vendored M3Shapes C++ implementation.
