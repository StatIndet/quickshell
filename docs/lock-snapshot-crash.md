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

Lock capture now uses `scripts/capture/LockSnapshot.qml`, a standalone Quickshell
config with a native ScreencopyView. The initial grim workaround was removed at
the user's request. This adds no external screenshot dependency.

The short-lived helper keeps its native context alive until process exit, without
clearing captureSource in frame callbacks. It isolates the known output-object
bug from the main shell's long-lived Wayland connection, rather than patching the
installed Qt/Quickshell binaries. The shell wrapper bounds it to 1.5 seconds plus
200 ms kill grace; QML bounds the whole request to 1800 ms. Outputs run concurrently.
A private temporary BMP bridges the processes; its local path is returned over
stdout. The main process preloads it and holds the pixmap cache entry before
requesting the session lock. The wrapper keeps the file until stdin release/EOF
and removes it with an EXIT trap. Display Images use the same URL and cache.
This replaces the former PNG/base64/data-URL round trip, which did not guarantee
synchronous decoding in the lock surface. An explicit lambda also ensures the
helper exits after saving instead of waiting for its deadline.
Stale responses cannot populate newer requests; completion is deferred until the
caller has received the request ID.

The reveal mask no longer depends on the asynchronously changing Image.Ready
state. It stays enabled from construction, and the scene remains transparent
until startup resolves. This prevents the full wallpaper/clock appearing before
the disc animation. Successful versus fallback startup is latched for the session.

If capture fails, authentication still starts. DefaultLock skips its masked
reveal and missing-snapshot exit fade, showing its wallpaper directly. Missing
wallpaper still has a solid theme surface as the final visual fallback.

## Validation limits

Quality checks do not exercise compositor timing. Validate real lock/unlock,
output removal, suspended outputs and rapid repeat requests in a graphical
session after loading the new code. Do not interpret a successful build/lint as
proof that every possible Quickshell crash is fixed.

## 2026-09-06 handoff timing refinement

The follow-up recording still showed a blank frame while the data-URL Image
loaded. Do not treat asynchronous:false on a data URL as a first-frame guarantee.
The new gate is receipt of the local BMP plus main-process Image.Ready with a
held cache entry; the lock surface then uses that exact URL synchronously.
This is an image-readiness gate, not a claim of measured compositor presentation.

Before changing the transport, a standalone instrumented helper run measured
about 310 ms through capture and a further 440 ms to save PNG. After changing to
BMP and explicit quit callback, three native requests produced files in
277–303 ms; each file remained accessible until release and was removed afterward.

A temporary standalone Quickshell harness also exercised the actual current
PreLockCapture twice, immediately starting request two after clearing request one.
On each completed signal, assigning the returned URL to a second cache-enabled
Image yielded Image.Ready synchronously. No session lock was requested. This
validates decoded-image handoff and rapid-repeat release, not compositor scanout.
