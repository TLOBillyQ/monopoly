---
name: verify-fast
description: "Run the common fast local confidence lane for this repo: guard checks, static architecture check, and behavior regression."
---

按顺序跑快速验证车道，任一失败就停下：

1. `lua tools/quality/lint.lua`（仅当本地装了 `luacheck`）
2. `lua tools/quality/encoding.lua check`
3. `busted --run guards`
4. `lua tools/quality/arch.lua check`
5. `busted --run behavior-smoke`

汇报：

- 每条命令通过/失败
- 在哪一步停下（如有）
- 扩大覆盖下一步建议跑什么（通常 `/verify-full`，或单独 `busted --run contract` / `busted --run regression`）

适用场景：日常 gameplay、runtime-flow、UI 或混合改动后的轻量信心扫。
