# Clavis sysmon JSON schema v1

`key sysmon` exposes one stable JSON envelope to the CLI, the QML
`SystemMonitorService`, and `key top`.

```json
{
  "schemaVersion": 1,
  "timestampMs": 1760000000000,
  "sequence": 42,
  "intervalMs": 1000,
  "system": {},
  "cpu": {},
  "memory": {},
  "gpus": [],
  "disks": [],
  "network": {},
  "battery": {},
  "errors": []
}
```

Only modules requested with `--modules` are present. `errors` is always
present. The default module set is `system,cpu,memory,gpu,disk,network,battery`;
it deliberately excludes `processes`.

## Conventions

- Field names are camelCase.
- Percentages end in `Percent` and use the `0..100` range.
- Byte totals end in `Bytes`; rates end in `BytesPerSecond`.
- Temperatures end in `Celsius`.
- CPU/GPU frequencies are expressed in MHz and end in `MHz`.
- Unix timestamps end in `Ms`; durations state `Ms` or `Seconds`.
- A supported numeric metric that cannot currently be read is JSON `null`.
- Objects expose `available`; optional hardware also exposes `supported` or
  `present`. A real measured zero remains the number `0`.
- Numbers use the locale-independent JSON representation.
- Diagnostics never replace the rest of a snapshot. They are appended to
  `errors` as `{ "module", "code", "message" }`.
- Protocol output is written only to stdout. Diagnostics that are not part of
  a snapshot go to stderr.

## Modules

### `system`

Contains hostname, OS/distribution, kernel, architecture, numeric uptime and
boot time, CPU model, logical CPU count, physical core count, and optional DMI
vendor/product/board/BIOS values. Compatibility session fields (`systemUser`,
`wmName`, `shellName`, `chassis`) may be present.

### `cpu`

Contains overall and per-core utilization (`coreIds` aligns with
`coreUsagePercent`), non-overlapping user/system/idle/iowait shares, frequency
current/average/range, CPU/package temperature, package power, and fan RPM when
readable. `sampleReady` is false on the first sample because utilization and
power need two monotonic counter readings.

### `memory`

Contains `totalBytes`, `usedBytes`, `availableBytes`, `freeBytes`,
`cachedBytes`, `buffersBytes`, `swapTotalBytes`, `swapUsedBytes`, and
`usagePercent`.
`usedBytes` is `MemTotal - MemAvailable`; reclaimable cache is not treated as
permanently used memory. `freeBytes` is the kernel's `MemFree` value and is
intentionally distinct from `availableBytes`.

### `gpus`

An array supporting NVIDIA, AMD, and Intel devices. Each entry contains stable
identity/vendor/driver fields and nullable utilization, temperature, VRAM,
power, and frequency metrics. An empty array means no GPU was detected;
`supported: false` means a GPU exists but its driver exposes none of these
metrics.

### `disks`

An array of meaningful mounted filesystems with mount point, filesystem,
device, capacity, usage, read/write byte rate, and optional read/write IOPS.
Rates are null until a previous counter for the same block device exists.

### `network`

Contains the lowest-metric active IPv4/IPv6 default route interface, aggregate
non-loopback totals/rates, and an `interfaces` array with `ifIndex`, link state,
loopback/wireless flags, totals, and rates. Top-level `wifiAvailable` and
`wifiConnected` summarize wireless link state. The legacy
`wirelessSignalPercent` and `wifiSignalPercent` keys remain null for v1 wire
compatibility; shell UI consumers use Quickshell's NetworkManager service for
signal strength. Counter reset, interface replacement, or reconnect produces
a null rate for that sample instead of an unsigned underflow spike.

### `battery`

Contains `present`, charging status, `chargePercent`, power, remaining seconds,
AC state, health, and energy/design capacities when reliable. A desktop without
a battery is valid: `available: true`, `present: false`.

### `processes`

Collected only for `key top`, `key sysmon processes`, or an explicit
`--modules processes`. Each row provides PID, PPID, name, full command, user,
state, CPU usage, memory bytes/percent, thread count, start time, runtime,
executable path, and optional derived `treeDepth`. PID plus start ticks is used
as the sampling identity to avoid PID-reuse spikes.

## JSON Lines

`key sysmon stream --format jsonl` emits one compact, complete JSON object
followed by `\n` for every sample and flushes after each line. A consumer must
validate `schemaVersion` before applying a line. A malformed or unsupported
line must not replace the last valid state.
