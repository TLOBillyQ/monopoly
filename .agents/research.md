# 架构审查快照（2026-03-07）

规范性文档：`docs/architecture/layer-model.md`

## 当前状态

6/6 主边界全部合规，无违规，无待办。

## 修复历史

| 违规 | 方案 |
|------|------|
| systems → Agent（5 文件） | 引入 AutoPlayPort + AutoPlayPortAdapter，Port 为纯 assert 契约 |
| systems → Bankruptcy（3 文件） | 引入 BankruptcyPort + BankruptcyPortAdapter，同上 |
| Port 文件含 fallback require | 去除，改为缺 port 时 assert 报错 |
| src/game/runtime/ 语义未定义 | boundaries.md 已补充 adapter 语义说明 |

dep_rules 新增：`systems ↛ game.core.runtime`（L142-149）

## 定量基线

```
回归测试: 376
dep_rules/tick/forbidden_globals: ok
growth_budget: within budget
Port fallback require: 0
```
