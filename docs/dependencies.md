# Dependencies

The source of truth is [`packaging/dependencies.json`](../packaging/dependencies.json).
Release tooling generates PKGBUILD dependency fields from this inventory. `defaultInstall`
selects the full installation profile; optional authorization and vendor GPU drivers are never implicit.

Runtime-only dependencies are assigned in package functions, so this repository builds and
tests independently of other Clavis repositories. CI installs only build, check and CI entries.

## Build

| Arch package | Purpose | Full install |
| --- | --- | --- |
| `cmake` | Native configuration | Yes |
| `ninja` | Native build | Yes |
| `pkgconf` | Native dependency discovery | Yes |
| `qt6-base>=6.8` | Native Qt Core, GUI and DBus | Yes |
| `qt6-declarative` | Native QML modules | Yes |
| `qt6-wayland` | Gamma protocol client | Yes |
| `qt6-shadertools` | Shader compiler | Yes |
| `qt6-tools` | LinguistTools | Yes |
| `qtkeychain-qt6` | Keychain headers | Yes |
| `libpipewire` | PipeWire headers | Yes |
| `libcava` (AUR) | Cava headers and shared library | Yes |
| `systemd-libs` | libudev headers | Yes |
| `libxkbcommon` | Keyboard headers | Yes |

## Tests

| Arch package | Purpose | Full install |
| --- | --- | --- |
| `python` | Script contract tests | Yes |
| `jq` | Matugen tests | Yes |
| `matugen` | Matugen tests | Yes |
| `git` | Isolated source archive contract fixtures | Yes |

## CI quality tools

This phase is used only in CI; these tools are not installer runtime requests.

| Arch package | Purpose | Full install |
| --- | --- | --- |
| `actionlint` | GitHub Actions workflow validation | CI only |
| `clang` | C++ formatting | Yes |
| `shellcheck` | Shell quality checks | Yes |
| `python` | Release tooling | Yes |
| `git` | Source version and diff checks | Yes |
| `quickshell` | QML shell runtime; validated baseline 0.3.1 | Yes |
| `qt6-base>=6.8` | Core, GUI, network and DBus | Yes |
| `qt6-declarative` | Qt Quick and QML | Yes |
| `qt6-svg` | SVG icons | Yes |
| `qt6-wayland` | Wayland client and gamma control | Yes |
| `qt6-5compat` | GraphicalEffects | Yes |
| `qt6-lottie` | Qt.labs.lottieqt weather animation | Yes |
| `qt6-location` | QtLocation maps | Yes |
| `qt6-positioning` | Geographic coordinates | Yes |
| `maplibre-native-qt` | MapLibre 3.0 and maplibre location plugin | Yes |
| `qtkeychain-qt6` | Weather map credential storage | Yes |
| `libpipewire` | Live audio capture | Yes |
| `libcava` (AUR) | Cava shared library, not the cava executable | Yes |
| `systemd-libs` | libudev device notifications | Yes |
| `libxkbcommon` | Shortcut key names | Yes |
| `qt6-m3shapes-git` (AUR) | External M3Shapes QML plugin | Yes |
| `ttf-material-symbols-variable` | Material Symbols Rounded and Outlined | Yes |
| `bash` | Runtime shell scripts | Yes |
| `python` | Niri configuration tools; vendored kdl parser | Yes |
| `coreutils` | File operations and timeout | Yes |
| `findutils` | Wallpaper discovery | Yes |
| `util-linux` | flock for Matugen registry | Yes |
| `which` | External program discovery | Yes |
| `jq` | Matugen registry JSON | Yes |
| `matugen` | Material theme generation | Yes |
| `xdg-utils` | Application defaults and opening URLs | Yes |
| `glib2` | GSettings and gio | Yes |
| `libnotify` | Desktop notifications | Yes |

## clavis-shell runtime

| Arch package | Purpose | Full install |
| --- | --- | --- |
| `quickshell` | QML shell runtime; validated baseline 0.3.1 | Yes |
| `niri` | Wayland compositor and session lifecycle | Yes |
| `key-cli>=2026.9.12` (AUR) | Shell lifecycle, recording, clipboard and keyboard protocol v1 | Yes |
| `keytop>=2026.9.12` (AUR) | JSONL system metrics protocol v1 | Yes |
| `qt6-base>=6.8` | Core, GUI, network and DBus | Yes |
| `qt6-declarative` | Qt Quick and QML | Yes |
| `qt6-svg` | SVG icons | Yes |
| `qt6-wayland` | Wayland client and gamma control | Yes |
| `qt6-5compat` | GraphicalEffects | Yes |
| `qt6-lottie` | Qt.labs.lottieqt weather animation | Yes |
| `qt6-location` | QtLocation maps | Yes |
| `qt6-positioning` | Geographic coordinates | Yes |
| `maplibre-native-qt` | MapLibre 3.0 and maplibre location plugin | Yes |
| `qtkeychain-qt6` | Weather map credential storage | Yes |
| `libpipewire` | Live audio capture | Yes |
| `libcava` (AUR) | Cava shared library, not the cava executable | Yes |
| `systemd-libs` | libudev device notifications | Yes |
| `libxkbcommon` | Shortcut key names | Yes |
| `qt6-m3shapes-git` (AUR) | External M3Shapes QML plugin | Yes |
| `ttf-material-symbols-variable` | Material Symbols Rounded and Outlined | Yes |
| `bash` | Runtime shell scripts | Yes |
| `python` | Niri configuration tools; vendored kdl parser | Yes |
| `coreutils` | File operations and timeout | Yes |
| `findutils` | Wallpaper discovery | Yes |
| `util-linux` | flock for Matugen registry | Yes |
| `which` | External program discovery | Yes |
| `jq` | Matugen registry JSON | Yes |
| `matugen` | Material theme generation | Yes |
| `xdg-utils` | Application defaults and opening URLs | Yes |
| `glib2` | GSettings and gio | Yes |
| `libnotify` | Desktop notifications | Yes |
| `systemd` | User service and application scopes | Yes |
| `pam` | Lock screen authentication | Yes |
| `sed` | Theme name normalization | Yes |
| `grep` | Theme filtering | Yes |
| `wl-clipboard` | Copy editor curves and clipboard integration | Yes |

## clavis-shell optional

| Arch package | Purpose | Full install |
| --- | --- | --- |
| `gpu-screen-recorder` | Screen recording through key-cli | Yes |
| `ffmpeg` | Audio recording, ffprobe and GIF conversion | Yes |
| `libpulse` | pactl audio source discovery | Yes |
| `slurp` | Recording region selection | Yes |
| `grim` | Screenshot capture | Yes |
| `hyprpicker` | Color picker | Yes |
| `awww` | Optional wallpaper backend | Yes |
| `rclone` | Cloud upload and backup | Yes |
| `brightnessctl` | Backlight control | Yes |
| `ddcutil` | External display brightness | Yes |
| `imagemagick` | Overview wallpaper cache tool | Yes |
| `xdg-terminal-exec` | Terminal file manager launch | Yes |
| `ttf-lxgw-wenkai-screen` (AUR) | Default UI font | Yes |
| `ttf-jetbrains-mono-nerd` | Default monospace and numeric font | Yes |
| `networkmanager` | Network controls and nmcli | Yes |
| `bluez` | Bluetooth service | Yes |
| `upower` | Power and battery service | Yes |
| `pipewire` | Audio server | Yes |
| `wireplumber` | Audio session manager when none is installed | Yes |
| `gsettings-desktop-schemas` | Desktop color scheme schema | Yes |
| `paru` (AUR) | Unused PackageService package counters; not needed by the installer | No |

## Bundled resources

Google Sans Flex and its license are tracked in `assets/fonts/google-sans-flex`. Material
Symbols Rounded/Outlined are supplied by `ttf-material-symbols-variable`; an already installed
compatible provider is retained. Shell font settings keep their existing fallback behavior.

Meteocons SVG 0.1.0 and Lottie 0.1.0 are fetched from fixed npm registry URLs with SHA-256
verification during release-source preparation. No npm runtime or first-launch download is needed.
The source archive contains SVG fill/flat/line/monochrome, Lottie fill, and the upstream MIT notice.
M3Shapes remains an external QML module and is never built or vendored by Clavis.

The Arch baseline is Quickshell 0.3.1 with networking, Bluetooth, PAM, PipeWire and UPower
enabled. Clavis native gamma control requires Qt 6.8 or newer. `libcava` must supply the
shared library and pkg-config interface; installing the `cava` command alone is insufficient.

NetworkManager, BlueZ, UPower and PipeWire must be usable in the session. Installation does
not switch audio servers, replace GPU drivers, enable system daemons, add device groups or
configure a credential store. DDC/backlight access uses distribution udev/logind policy.
Map-provider credentials and Rclone authentication are supplied by the user in the existing UI.

### Weather place names

Saved weather coordinates are reverse-geocoded through Nominatim. Forecasts always
use the original coordinates; the returned city/town/region is only a display name.
Successful names are cached in Clavis Weather settings; failed lookups back off for
24 hours and retain the coordinate label. Names use the service's local-language
response. Requests are serialized with at least 1.1 seconds between network lookups,
with an identifying User-Agent and a compact map-corner attribution for OpenFreeMap, OpenMapTiles, and OpenStreetMap
in both location picker views.
Map dragging does not perform lookups.

The [public Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/)
limits aggregate application traffic to 1 request/second and requires caching and
attribution. Larger deployments must use a suitable provider or their own instance.
Set `CLAVIS_GEOCODING_URL` to a compatible reverse endpoint to change providers
without updating Clavis. The endpoint receives the saved coordinates; cached results
are scoped to the endpoint. IP-based automatic location continues to use ipwho.is.
