# Lock screen styles

Settings Center → Theme → Lock screen selects `default` or `caelestia`.
The selection is saved as `theme.lockScreenStyle` in the personalization config.
Missing or invalid values use `default`; each lock session keeps its initial selection.

`CaelestiaLock.qml` preserves the original card layout. `DefaultLock.qml` reveals a
blurred wallpaper over the frozen pre-lock desktop frame, with authentication UI
in `DefaultLockContent.qml`. Both styles share the session lock and PAM context.
The new style uses Qt Quick MultiEffect for blur and the circular reveal mask.

During development, every output has a **let me out** button outside the animated
content. It aborts PAM and releases the session lock without a password, as requested.
Remove this development escape hatch before a production lock-screen release.

Manual visual checks in a graphical session:

- Select each style and lock using the normal shell action.
- Verify the default style with image/solid-color wallpaper and multiple outputs.
- Verify 12-hour AM/PM and 24-hour clocks, and the date at midnight.
- Type, delete, submit an incorrect password, then authenticate successfully.
- Press Escape to clear input and restore the clock; click to reveal authentication.
- Verify the emergency exit remains clickable during entrance and authentication.

No real session lock is started by development checks.
