# 导读

**蛋仔派对大富翁** — Lua 5.5，清洁架构七层 + foundation，Eggy 宿主。

Agent 路由：`.agents/README.md` | 人类索引：`docs/README.md`

## 常驻规则

- 命名 `snake_case`，类名 `CamelCase`。
- `src/` 禁用 `tonumber` / `type == "number"`，用 `NumberUtils`（`src.foundation.lang.number`）。
- Eggy `Fixed` 参数用浮点（`30.0`），详见 `.agents/conventions/eggy-types.md`。

## 验证

`lua tools/quality/lint.lua` + `busted --run <profile>`（profile 见 `.agents/README.md`）
