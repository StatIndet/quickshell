# Arch installation

The first release targets Arch-compatible x86_64 systems. The three independent projects
are distributed as `clavis-shell`, `key-cli` and `keytop`. `clavis` is an unrelated AUR package.
No public release or AUR package is implied merely by this documentation being present;
the commands become usable after the first [release](releasing.md) is published.

## One command

```bash
curl -fsSL https://raw.githubusercontent.com/StatIndet/quickshell/main/install.sh | bash
```

Run as the desktop user, not root. Bash, curl, coreutils and sudo are prerequisites.
The raw entry point selects the latest completed date release, downloads its installer,
and verifies its SHA-256 against that release's checksum list. HTTPS and the repository
are the trust boundary; the checksum detects corruption, not compromise of that repository.
The complete verified installer runs only after the download succeeds. It bootstraps Python
if absent, then installs official dependencies and builds AUR sources as your user.
No AUR helper is required. Pacman owns installed files and handles removal and upgrades.
The initial `pacman -Syu` keeps Arch synchronized; review its normal transaction prompt.

To inspect the requested packages without installing:

```bash
curl -fsSL https://raw.githubusercontent.com/StatIndet/quickshell/main/install.sh | bash -s -- --dry-run
```

Without Python, dry-run prints the bootstrap requirement and package requests without installing it.
The installer includes the full optional-feature profile from [dependencies](dependencies.md).
Existing dependency providers are retained. It does not replace drivers or audio services,
write Niri configuration, set PATH, remove source installations, or restart running processes.
AUR `PKGBUILD` files execute code as your user; their checksums protect upstream source integrity.

## Explicit choices

The installer reads prompts through `/dev/tty`, including when stdin comes from curl.
All five prompts default to `[Y/n]`:

- Keyboard access: grants access to whole matching evdev keyboard nodes, including raw
  keystrokes, to active local users. This is broader than reading lock LEDs.
- keytop access: grants `cap_perfmon` and `cap_dac_read_search`, including broad read-permission
  bypass. Ordinary CPU usage does not need them; supported RAPL power sensors may.
- Enable Clavis Shell with the Niri user service.
- Enable the separate clipboard-history watcher with the Niri user service.
- Start both services now, if `niri.service` is active, independently of the autostart choices.
  Active services are not restarted.

For unattended use every choice must be explicit:

```bash
curl -fsSL https://raw.githubusercontent.com/StatIndet/quickshell/main/install.sh | bash -s -- \
  --non-interactive \
  --keyboard-access=no --power-access=no \
  --enable-shell=no --enable-clipboard=no --start-now=no
```

`--non-interactive` also accepts pacman transactions without prompting. There is no general
`--yes` that grants permissions. `no` skips new authorization/activation; it does not revoke
an existing administrator policy or disable an existing service. Repeated interactive
installations retain recorded permission choices and current service enablement, without
restarting or asking again. Choices are saved under `$XDG_STATE_HOME/clavis/installer/choices.json`
(default `~/.local/state`). Invalid state files are preserved for manual review.

Authorization is separate from the base packages:

- `key-cli-keyboard-access` supplies the udev rule. Removing it removes the persistent rule;
  existing ACLs/descriptors and other rules may still grant access. Reconnect the device and
  log in again before checking actual access.
- `keytop-privileged-access` applies capabilities using a pacman transaction hook, reapplies
  them when keytop is upgraded, and removes matching capabilities before its own removal.
  Unexpected capabilities, non-package-owned files, symlinks and writable installation paths
  are preserved/rejected for manual review. Already running processes may retain access.

The installer leaves existing `/etc`, `/run` or `/usr/local` keyboard rules untouched and
reports them instead of silently layering a new rule underneath them.

## Existing installations and sessions

System files are installed under `/etc/xdg/quickshell/clavis`, `/usr/lib/qt6/qml/Clavis`,
and `/usr/lib/systemd/user`. User configuration remains in the existing XDG locations.
`~/.config/quickshell/clavis`, `/usr/local/bin/key`, development venvs, environment overrides
and systemd drop-ins can select an older source installation. The installer reports these
and skips activation rather than removing them. Withdraw development overrides through the
existing key-cli installation tooling, then select the intended service yourself.

If no Niri user session is active, enabled units take effect in the next such session.
The installer never starts Niri, NetworkManager, Bluetooth or an audio server. It reports
session prerequisites and `key doctor --json`; missing hardware/authorization may leave
specific features unavailable while ordinary metrics continue working.

A failed step returns nonzero and identifies the stage. Successfully installed packages
remain pacman-owned; fix the reported cause and rerun. There is no application rollback
manager. For direct AUR installation, build `libcava` and `qt6-m3shapes-git` as needed,
then `key-cli`, `keytop`, and `clavis-shell`; an existing AUR helper can resolve this graph.
Installing only the base packages never grants the two optional access policies or enables
user services. Standard pacman/AUR tooling remains the normal upgrade and removal path.
