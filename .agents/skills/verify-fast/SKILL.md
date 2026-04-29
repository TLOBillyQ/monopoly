---
name: verify-fast
description: Run the common fast local confidence lane for this repo: guard checks, static architecture check, and behavior regression.
---

按以下顺序跑快速验证车道，前一步失败就停下：

1. `lua tools/quality/lint.lua`（仅当本地装了 `luacheck`）
2. `busted --run guards`
3. `lua tools/quality/arch.lua check`
4. `busted --run behavior`

跑完后汇报：

- 每条命令的通过/失败结果
- 在哪一步因失败停下（如有）
- 想要更宽覆盖时下一条该跑什么命令（通常是 `/verify-full`，或单独 `busted --run contract` / `busted --run regression`）

适用场景：日常 gameplay、runtime-flow、UI 或混合改动后想要一次轻量信心扫。