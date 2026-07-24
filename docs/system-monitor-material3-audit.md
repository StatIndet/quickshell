# System monitor Material 3 code audit

- **Target:** `Modules/Sidebars/Left/SystemView.qml` and
  `Modules/Sidebars/Left/system/*.qml`
- **Date:** 2026-07-23
- **Method:** Static source review against the repository's installed Material 3
  skill, including its color-pairing, type-scale, shape, tonal-elevation,
  adaptive-layout, motion, and accessibility criteria.
- **Overall score:** **86/100** (previous source-review pass: 81/100)

This is a code-level compliance audit. It is **not** a completed visual
acceptance test. Screenshot comparison, perceived proportions, clipping,
contrast in the active generated palette, and behaviour on the user's actual
displays remain subject to the user's manual visual inspection.

## Re-audited fixes

- The clipped battery fill's paint-only copy is excluded from the accessibility
  tree at `Modules/Sidebars/Left/system/SystemBatteryTank.qml:61`.
- `SystemSparkline` now accepts caller-provided accessible names and
  descriptions at `Modules/Sidebars/Left/system/SystemSparkline.qml:20`;
  metric and network callers provide current-value context at
  `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:166` and
  `Modules/Sidebars/Left/system/SystemNetworkCard.qml:133`.
- The retry button now has an explicit 48 px minimum target at
  `Modules/Sidebars/Left/system/SystemUnavailableState.qml:71`.
- The short-screen scroll region is focusable and implements arrow,
  Page Up/Down, Home, and End navigation at
  `Modules/Sidebars/Left/SystemView.qml:322` and
  `Modules/Sidebars/Left/SystemView.qml:335`.
- Battery width is clamped while preserving at least 168 px for the network
  card at `Modules/Sidebars/Left/SystemView.qml:384`.

## Scores by category

| Category | Score | Status | Source evidence | Remaining improvement |
| --- | ---: | --- | --- | --- |
| Color | 9/10 | Pass | Runtime status uses matched container/on-container roles in `Modules/Sidebars/Left/SystemView.qml:40`; CPU, memory, and GPU cards receive primary, tertiary, and secondary role pairs in `Modules/Sidebars/Left/SystemView.qml:422`, `Modules/Sidebars/Left/SystemView.qml:472`, and `Modules/Sidebars/Left/SystemView.qml:530`. The battery's clipped fill switches from `secondaryContainer/onSecondaryContainer` to `secondary/onSecondary` in `Modules/Sidebars/Left/system/SystemBatteryTank.qml:37` and `Modules/Sidebars/Left/system/SystemBatteryTank.qml:55`. The audited files contain no literal hex/RGB surface colors. | Manually verify the tertiary/primary throughput text against every generated light/dark palette at `Modules/Sidebars/Left/system/SystemNetworkCard.qml:98` and the secondary storage percentage at `Modules/Sidebars/Left/system/SystemStorageCard.qml:92`; use `onSurface` plus a colored icon if a palette misses 4.5:1. |
| Typography | 8/10 | Pass | Titles, body copy, labels, and supporting text consistently use the shared `Sizes.type*` scale and project font families, for example `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:122`, `Modules/Sidebars/Left/system/SystemDetailsCard.qml:100`, and `Modules/Sidebars/Left/system/SystemStorageCard.qml:77`. Metrics intentionally use the mono family in `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:183`. | Replace the raw metric sizes `36`, `48`, and `30` with named shared type tokens or explicit metric tokens at `Modules/Sidebars/Left/SystemView.qml:421`, `Modules/Sidebars/Left/SystemView.qml:469`, and `Modules/Sidebars/Left/SystemView.qml:527` so later type-scale changes remain coherent. |
| Shape | 9/10 | Pass | Cards use the shared extra-large corner token in `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:44`, `Modules/Sidebars/Left/system/SystemNetworkCard.qml:18`, and `Modules/Sidebars/Left/system/SystemStorageCard.qml:20`. Expressive shapes vary by function and load, including utilization-driven morph selection in `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:32`, battery-state morphing in `Modules/Sidebars/Left/system/SystemBatteryTank.qml:100`, and the system-card ClamShell in `Modules/Sidebars/Left/system/SystemDetailsCard.qml:78`. | Reconsider the smaller error-state corner at `Modules/Sidebars/Left/system/SystemUnavailableState.qml:18` during manual inspection; if it reads as belonging to another component family, use the same extra-large card token as the dashboard cards. |
| Elevation | 9/10 | Pass | Depth is expressed through tonal surfaces rather than drop shadows: the header uses `surfaceContainerLow` at `Modules/Sidebars/Left/SystemView.qml:160`, the network card uses `surfaceContainer` at `Modules/Sidebars/Left/system/SystemNetworkCard.qml:18`, and storage/details use `surfaceContainerHigh` at `Modules/Sidebars/Left/system/SystemStorageCard.qml:20` and `Modules/Sidebars/Left/system/SystemDetailsCard.qml:68`. | If manual inspection shows adjacent high-tonal cards merging, adjust their semantic surface-container level at `Modules/Sidebars/Left/system/SystemStorageCard.qml:20` and `Modules/Sidebars/Left/system/SystemDetailsCard.qml:68`; do not add decorative shadows by default. |
| Components | 9/10 | Pass | Standard actions and asynchronous states use Qt Quick Controls with the Material style: the full-monitor `Button` is at `Modules/Sidebars/Left/SystemView.qml:242`, `BusyIndicator` at `Modules/Sidebars/Left/system/SystemLoadingState.qml:18`, and `ProgressBar` plus the now-explicit 48 px retry `Button` at `Modules/Sidebars/Left/system/SystemUnavailableState.qml:63` and `Modules/Sidebars/Left/system/SystemUnavailableState.qml:71`. Custom QML is reserved for system-specific visualization, clipping, charts, and M3Shapes. | The read-only status pill remains a hand-built `Rectangle` at `Modules/Sidebars/Left/SystemView.qml:206`; if a suitable Material chip becomes available in the project's Qt version, migrate it while preserving the current semantic role pairing. |
| Layout | 8/10 | Pass | The dashboard uses available content height on normal displays and becomes scrollable only below the readable 760 px content minimum in `Modules/Sidebars/Left/SystemView.qml:19` and `Modules/Sidebars/Left/SystemView.qml:310`. Explicit row geometry starts at `Modules/Sidebars/Left/SystemView.qml:372`; CPU, root storage, and system details have concrete regions at `Modules/Sidebars/Left/SystemView.qml:400`, `Modules/Sidebars/Left/SystemView.qml:583`, and `Modules/Sidebars/Left/SystemView.qml:590`. The battery clamp at `Modules/Sidebars/Left/SystemView.qml:384` now protects a 168 px network minimum. | Add a true narrow-width composition around the resource and support splits at `Modules/Sidebars/Left/SystemView.qml:382` and `Modules/Sidebars/Left/SystemView.qml:391`; the 58/42 columns can still become cramped if the entire sidebar width is reduced substantially, even though the network/battery pair is now protected. |
| Navigation | 9/10 | Pass | Primary destination switching belongs to the parent sidebar and is outside this file's scope. Within this destination, the route-changing action is clearly named and described at `Modules/Sidebars/Left/SystemView.qml:242`. The short-screen fallback is tab-focusable and named at `Modules/Sidebars/Left/SystemView.qml:322`, with arrow, Page Up/Down, Home, and End handling at `Modules/Sidebars/Left/SystemView.qml:335`. | During manual keyboard inspection, confirm that focus is visibly distinguishable on the scroll region at `Modules/Sidebars/Left/SystemView.qml:310`; if the platform style supplies no indicator, add a token-backed `outline` focus treatment without changing the non-scrollable state. |
| Motion | 8/10 | Pass | Color, size, and rotation transitions use shared motion timing in `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:56` and `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:82`. The sparkline slides one sample interval and animates its scale at `Modules/Sidebars/Left/system/SystemSparkline.qml:66` and `Modules/Sidebars/Left/system/SystemSparkline.qml:77`, uses smooth Bézier interpolation at `Modules/Sidebars/Left/system/SystemSparkline.qml:148`, and stops canvas work while inactive at `Modules/Sidebars/Left/system/SystemSparkline.qml:85`. Battery level changes animate through a shared spatial token at `Modules/Sidebars/Left/system/SystemBatteryTank.qml:28`. | Add an application-level reduced-motion multiplier or bypass at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:78`, `Modules/Sidebars/Left/system/SystemBatteryTank.qml:28`, and `Modules/Sidebars/Left/system/SystemSparkline.qml:66`; the current source has no visible reduced-motion path. |
| Accessibility | 8/10 | Pass | Main and retry actions have 48 px targets and accessible names at `Modules/Sidebars/Left/SystemView.qml:245` and `Modules/Sidebars/Left/system/SystemUnavailableState.qml:71`. Metric, network, battery, storage, and system cards expose summaries at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:47`, `Modules/Sidebars/Left/system/SystemNetworkCard.qml:21`, `Modules/Sidebars/Left/system/SystemBatteryTank.qml:24`, `Modules/Sidebars/Left/system/SystemStorageCard.qml:23`, and `Modules/Sidebars/Left/system/SystemDetailsCard.qml:71`. Charts expose caller-provided time range and current values through `Modules/Sidebars/Left/system/SystemSparkline.qml:20`; the clipped battery copy is ignored at `Modules/Sidebars/Left/system/SystemBatteryTank.qml:61`; short-screen keyboard access is implemented at `Modules/Sidebars/Left/SystemView.qml:322`. | Run a live accessibility-tree traversal before raising this category further. If custom `Rectangle`/`Item` summaries are not exposed consistently, add explicit read-only roles at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:47`, `Modules/Sidebars/Left/system/SystemNetworkCard.qml:21`, and the other card roots; if decorative glyphs are announced, suppress their shape subtrees beginning at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:65` and `Modules/Sidebars/Left/system/SystemNetworkCard.qml:57`. |
| Theming | 9/10 | Pass | All audited colors flow through semantic `Appearance.colors` roles, while spacing and corners use shared `Appearance.spacing` and `Appearance.rounding` tokens. Examples include the header at `Modules/Sidebars/Left/SystemView.qml:153`, metric defaults at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:20`, and the network chart at `Modules/Sidebars/Left/system/SystemNetworkCard.qml:124`. This keeps the page connected to the repository's generated light/dark theme rather than a page-local palette. | The source structure is theme-ready, but generated-palette contrast is not proven by this static audit. Manually inspect the role applications at `Modules/Sidebars/Left/SystemView.qml:422`, `Modules/Sidebars/Left/SystemView.qml:472`, and `Modules/Sidebars/Left/SystemView.qml:530` in both light and dark modes and at any supported contrast setting. |

## Priority fixes and validation

1. **Finish human visual acceptance.** Inspect the explicit height allocation at
   `Modules/Sidebars/Left/SystemView.qml:372` on the current display (all cards
   visible without scrolling) and below the 760 px content threshold
   (scrolling available), plus no-GPU, no-battery, long-label, light-theme, and
   dark-theme states. This acceptance step is intentionally left to the user.
2. **Verify contrast with generated palettes.** Measure the dynamic accent text
   at `Modules/Sidebars/Left/system/SystemNetworkCard.qml:98` and
   `Modules/Sidebars/Left/system/SystemStorageCard.qml:92` in supported theme
   modes instead of inferring contrast from token names.
3. **Add reduced-motion support.** Route animation duration through a shared
   preference at `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:78`,
   `Modules/Sidebars/Left/system/SystemBatteryTank.qml:28`, and
   `Modules/Sidebars/Left/system/SystemSparkline.qml:66`.
4. **Add a narrow-width composition.** Introduce a width breakpoint around
   `Modules/Sidebars/Left/SystemView.qml:382` so resource and support columns
   can stack rather than being compressed. The separate network/battery clamp
   at `Modules/Sidebars/Left/SystemView.qml:384` is already correct.
5. **Verify the live accessibility tree.** Test focus order, card summaries,
   chart descriptions, and decorative glyph exposure beginning at
   `Modules/Sidebars/Left/SystemView.qml:322` and
   `Modules/Sidebars/Left/system/ExpressiveMetricTile.qml:47`.
6. **Complete type-token cleanup.** Replace raw metric sizes at
   `Modules/Sidebars/Left/SystemView.qml:421`,
   `Modules/Sidebars/Left/SystemView.qml:469`, and
   `Modules/Sidebars/Left/SystemView.qml:527` with named tokens.

## Audit boundary

This report does not assert that manual visual checks have passed. It also does
not replace `qmllint`, runtime smoke tests, live accessibility-tree inspection,
or contrast measurement against generated palettes. Those validations should
be recorded separately from this source-level MD3 score.
