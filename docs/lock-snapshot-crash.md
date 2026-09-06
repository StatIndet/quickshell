# Lock snapshot crash investigation — 2026-09-06

The five latest reports examined were `e6j8lr3ykt`, `e6j8rq3ykt`,
`e6j8zc3ykt`, `e6j8ma3ykt`, and `e6j8pv2ykt` under
`~/.cache/quickshell/crashes/`. All have the same Qt Wayland SIGSEGV stack.
This was investigated without starting a session lock or restarting Quickshell.

## Evidence

- System core dump PID 430079 preserves the original fault in frame 4, below
  Quickshell's signal handler. Qt Wayland build ID is
  `d360eddd9091e77f43eb42e6c1ffee92ef921ad8`.
- Matching Arch debuginfo resolves offset `0x63b82` to
  `QtWaylandClient::QWaylandSurface::surface_enter(wl_output*) [clone .cold]`.
- The faulting instruction is `call *0x90(%rax)` with `rax = 0`.
  Qt is accessing the object 16 bytes before the output wrapper pointer.
- GDB resolves the actual wrapper's vtable to
  `qs::wayland::screencopy::wlr::WlrScreencopyContext::OutputTransformQuery`.
  This is the extra output object created by the installed Quickshell WLR
  screencopy implementation, not a Qt QWaylandScreen. This establishes the
  incorrect object interpretation in the latest core; the other four reports
  have matching stacks but were not individually inspected at object level.
- Decoded latest-instance logs record capture deadlines at 22:01:04, 22:01:19,
  22:01:41 and 22:06:28. The former 300 ms deadline discarded missing frames,
  after which DefaultLock revealed over an empty Image. The logs establish
  timeout failures, not whether GPU allocation or frame readback consumed the time.

## Local fix

Lock capture uses a separate `grim` Wayland client, already used by the project's
screenshot command. Its PNG is base64-encoded over stdout; no screenshot files
are created. The helper propagates failures through `pipefail`, bounds grim to
one second with a 200 ms kill grace, and the QML request has a 1500 ms deadline.
Per-output requests run concurrently. Stale responses cannot populate a newer
request. Completion is deferred so callers receive the request ID first.

The lock no longer creates ScreencopyView, screenshot host PanelWindows or a
warmup view. This avoids the offending OutputTransformQuery path in this process;
it does not patch the installed Qt or Quickshell binaries. Other users of
ScreencopyView elsewhere may still encounter upstream defects.

If capture fails, authentication still starts. DefaultLock skips its masked
reveal and missing-snapshot exit fade, showing its wallpaper directly. Missing
wallpaper still has a solid theme surface as the final visual fallback.

## Validation limits

Quality checks do not exercise compositor timing. Validate real lock/unlock,
output removal, suspended outputs and rapid repeat requests in a graphical
session after loading the new code. Do not interpret a successful build/lint as
proof that every possible Quickshell crash is fixed.
