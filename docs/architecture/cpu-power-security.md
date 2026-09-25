# CPU 功耗读取边界

RAPL CPU 功耗由 `key-cli` 的原生采样器提供。Clavis Shell 只消费
`key sysmon stream` 的结果，不请求 sudo、不安装 capability，也不管理权限 helper。

```bash
key sysmon cpu --format json
key sysmon snapshot --format json --modules cpu,system,memory
```

不可读的 powercap 接口应报告 unsupported 或 permission denied，同时继续提供其他
系统指标。可选的 `key-cli-cpu-power-access` 仅授权固定路径的 `key-cpu-power`
helper；采样器和整个 Shell 保持普通用户权限。
