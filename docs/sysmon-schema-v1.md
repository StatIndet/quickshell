# keytop JSONL schema v1

系统监测唯一机器接口是：

```bash
keytop value stream --format jsonl --interval 1000 \
  --modules cpu,memory,gpu,disk,network
```

每行是一个完整 JSON 对象，包含 `schemaVersion: 1`、`timestampMs`、`sequence`、
`intervalMs` 以及请求到的 `cpu`、`memory`、`gpus`、`disks`、`network` 字段和
`errors`。不可用数值使用 `null`。Shell 直接消费并验证这些字段；没有 CLI 中转层。
Clavis 不从该 stream 请求 `system` 或 `battery`：前者使用一次性
`keytop value system --format json`，后者使用 Quickshell UPower。keytop 的 v1
协议仍完整保留 `system` 与 `battery` module，供自身 CLI/TUI 和其他消费者使用。
