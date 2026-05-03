# ADR 0002 — Foundation 与 State 边界（log_once 依赖反转）

**Status**: Accepted (2026-05-03)
**Builds on**: [ADR-0001 §D1（Foundation 不可依赖任何上层）](0001-seven-layer-with-foundation.md#d1--架构模型七层--foundation-基座)
**Driver**: `src/foundation/log/utils.lua` 历史遗留 `require("src.state.runtime_state")`，违反 D1 不变量。

> **Note**：本 ADR 在 ADR-0001 的"foundation 不可依赖任何上层"基础上做一处具体修复，并把"foundation 算法 / state 持有便利函数"作为同类问题的处置范式钉死。

---

## 上下文（Why）

ADR-0001 §D1 写"foundation 不可依赖任何上层"，§D7 又写"state ↔ foundation 是平级关系"（删除 `state_access` exception 时给的理由）。两条之间存在解读歧义：

- **D1 严格读**：foundation 不可依赖任何七层之一；state 是 L7，因此 foundation 不可依赖 state。
- **D7 宽松读**：state 与 foundation 平级；二者互不算上下游，foundation 可双向引用 state.runtime_state（因为后者是"运行期工具状态"而非业务状态）。

这个歧义在 `src/foundation/log/utils.lua:2` 上具体化：

```lua
-- src/foundation/log/utils.lua（修复前）
local logger = require("src.foundation.log.logger")
local runtime_state = require("src.state.runtime_state")  -- ⚠ 灰区

function logger_utils.log_once(state, level, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  if debug_runtime.log_once[key] then
    return false
  end
  debug_runtime.log_once[key] = true
  ...
end
```

`tools/quality/arch.lua check` 当前不报错（exception 表内无对应规则），但语义未明文锁死。每多一处类似引用，治理成本就放大一次。

---

## 决策（What）

### D1 — Foundation 严格无上行依赖

明确采用 ADR-0001 §D1 的严格读法：**foundation 不可 require 任何七层之一**，包括 state。`src/foundation/log/utils.lua` 是当前唯一违例点，按本 ADR 修复。

### D2 — log_once 算法参数化：foundation 只接 sink

`src/foundation/log/utils.lua` 的 `log_once` 改签名为 `(sink, level, key, ...)`，调用方传入一个去重映射表（map），foundation 只提供"按 key 去重 + 转发到 logger"的纯算法：

```lua
-- src/foundation/log/utils.lua（修复后）
local logger = require("src.foundation.log.logger")

local logger_utils = {}

function logger_utils.log_once(sink, level, key, ...)
  assert(type(sink) == "table", "missing dedupe sink")
  if sink[key] then
    return false
  end
  sink[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
  return true
end

return logger_utils
```

### D3 — State 持有便利函数 `runtime_state.log_once`

`src/state/runtime_state.lua` 新增 `log_once(state, level, key, ...)`：内部从 `debug_runtime.log_once` 取 sink，转发给 foundation 算法。

```lua
-- src/state/runtime_state.lua（新增）
local logger_utils = require("src.foundation.log.utils")
...
function runtime_state.log_once(state, level, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  return logger_utils.log_once(debug_runtime.log_once, level, key, ...)
end
```

调用方从 `logger_utils.log_once(state, ...)` 迁移到 `runtime_state.log_once(state, ...)`，外部签名不变，去重 sink 的归属上移到 state 层（语义正确：state 拥有运行期持久化的去重表）。

### D4 — Callback 风格 log_once 保留 `(state, level, key, ...)` 签名

`render` 管线（`canvas_render_pipeline` → `board.refresh` → `anchors`/`player_units`）通过 callback 把 `common.log_once` 注入下游模块。这条 callback 链不动，仅 `common.log_once` 与 `tick_ui_sync.log_once` 内部实现切换底层调用：
- `turn/waits/ui_sync.lua`（L4 turn 层）→ `runtime_state.log_once`（直接调用 state 层）
- `ui/ports/common.lua`（L3 ui 层）→ `ui_runtime_state.log_once`（**通过 ui 层 seam adapter `src/ui/state/runtime.lua`**）

理由：
- 渲染管线 callback 接口已稳定且对状态无知，改这条链对本 ADR 收益为零、回归面更大。
- ui 层不可直接 require `src.state.runtime_state`（dep_rules guard rule 03 已固化"presentation modules must consume runtime state through seam adapters"）。`src/ui/state/runtime.lua` 是既有的 ui→state 转译层，本 ADR 在其上新增 `log_once` 转发即可，无需新增 seam。

### D5 — 范式（同类问题的统一处置）

未来若 foundation 出现新的"似乎需要拿状态"的场景（如新去重器、新本地缓存），统一按本 ADR 模式处置：

1. foundation 暴露**纯算法 API**，参数化所有可变状态（sink/cache/handle）。
2. 在持有该状态的层（通常是 state 或 ui.state）写**便利函数**，把"取出可变状态 + 调用算法"打包。
3. 调用方使用便利函数；foundation 始终零向上引用。

**禁止**为单点问题新增 `_state_access` 类 exception，避免治理成本累积。

---

## 与 ADR-0001 的关系

| ADR-0001 决策点 | 本 ADR 处置 |
|---|---|
| §D1（foundation 不可依赖上层） | 收紧为严格无上行：state 也算上层 |
| §D7（state ↔ foundation 平级） | 修订理由：二者**地位平级**（都不属七层业务）但**依赖方向单向**（state→foundation），foundation 不可反向 require state |
| `state_access` exception 已删除 | 维持删除，本 ADR 不重新引入 |

ADR-0001 §D7 关于"state ↔ foundation 平级"的表述以本 ADR D1 为准：平级指**地位**，不指**依赖方向**。

---

## 完成判据

| 项 | 标准 |
|----|------|
| `src/foundation/log/utils.lua` 不 require state | `grep "require.*src\.state" src/foundation/ --include='*.lua'` 应为 0 |
| `runtime_state.log_once` 存在并可用 | `spec/contract/state/` 或 `spec/guards/` 验证 API |
| 5 个真实调用方与 2 个 re-export 已迁移 | grep `logger_utils.log_once` 在 src/ 下应只剩 0（被 runtime_state 内部包装） |
| arch.lua 无新增违规 | `lua tools/quality/arch.lua check` 通过 |
| Behavior 全绿 | `busted --run behavior` |
| Guards 全绿 | `busted --run guards` |

---

## 已识别的耦合影响

- **ui/ports/common.lua** 经 `src.ui.state.runtime` seam 调用 `log_once`，遵守 dep_rules rule 03（presentation 不可直接 require state）。
- **src/ui/state/runtime.lua** 新增一行 `log_once` 转发，与既有 `ensure_debug_runtime`/`is_ui_dirty`/`set_ui_model` 等转发同型，无新增模式。
- **turn/waits/ui_sync.lua** 与 **turn/loop/init.lua** 与 **turn/waits/choice_timeout.lua** 均已引用 `src.state.runtime_state`，仅本地切换函数体（turn 层无 dep_rules 限制）。
- **callback 链未变**：`render` 管线传递的 `common.log_once` 签名 `(state, level, key, ...)` 不变，board/anchors/player_units 零改动。
- **去重 sink 真源不变**：仍存放在 `state.debug_runtime.log_once`，`ensure_debug_runtime` 保证按需懒初始化，行为与修复前一致。

---

## 决策日期 / 作者

**Date**: 2026-05-03
**Author**: 执行者（按 `plans/src-soft-taco.md` P0-2 实施）
