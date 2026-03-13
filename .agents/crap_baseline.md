# CRAP 双 lane 基线（2026-03-13）

## 生成命令

- `lua scripts/crap.lua report --lane behavior --lane contract --out ./tmp/crap_report.json --top 300`

## 基线摘要

- 报告文件：`tmp/crap_report.json`
- 生成时间（UTC）：`2026-03-13T02:24:58Z`
- 统计函数数：`2580`
- `crap >= 10`：`0`
- `must_refactor`（complexity >= 10）：`0`
- `coverage_first`（complexity <= 9）：`0`

## 结论

当前双 lane 基线已无 `crap >= 10` 热点，`T2-T7` 的分桶重构无需再展开；后续仅需保持回归与双 lane CRAP 绿灯，防止回归。
