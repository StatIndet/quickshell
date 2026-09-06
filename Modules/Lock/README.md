# Lock screen styles

Settings Center → Theme → Lock screen selects `default` or `caelestia`.
The selection is saved as `theme.lockScreenStyle` in the personalization config.
Missing or invalid values use `default`; each lock session keeps its initial selection.

`CaelestiaLock.qml` preserves the original card layout. `DefaultLock.qml` reveals a
blurred wallpaper over a frozen pre-lock desktop frame, with authentication UI
in `DefaultLockContent.qml`. Both styles share the session lock and PAM context.
The new style uses Qt Quick MultiEffect for blur and the circular reveal mask.
Both styles capture the desktop through a bounded `grim` subprocess before acquiring
the session lock. PNG data is passed through stdout in memory, never saved to disk.
This needs `grim`, `timeout`, and `base64` (the latter two from coreutils). Default keeps
the snapshot underneath its wallpaper layer for the top-left disc reveal and exit
fade. The wallpaper itself is still sourced from the current wallpaper image.

Manual visual checks in a graphical session:

- Select each style and lock using the normal shell action.
- Verify the default style with image/solid-color wallpaper and multiple outputs.
- Verify 12-hour AM/PM and 24-hour clocks, and the date at midnight.
- Type, delete, submit an incorrect password, then authenticate successfully.
- Press Escape to clear input and restore the clock; click to reveal authentication.
- Verify entrance reveals the blurred wallpaper over the desktop snapshot without a black flash.

If capture fails or times out, locking still proceeds. Default shows the wallpaper
without a disc reveal or a fade to a missing snapshot. In-process ScreencopyView
and its warmup are intentionally not used for locking.

No real session lock is started by development checks.
