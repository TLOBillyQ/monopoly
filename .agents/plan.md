# 消除终局边界泄漏并补强依赖护栏

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。

## 目的 / 全局视角

当前代码库的目录边界已经基本成型，但仍残留两处关键的对象级/依赖级泄漏：

1. `src/game/core/player/state_ops/location_ops.lua` 直接依赖 `src/game.systems.endgame.bankruptcy`，形成 state → systems 的反向依赖。
2. `src/game/systems/endgame/bankruptcy.lua` 直接读取 `game.gameplay_loop_ports`，让 systems 通过对象字段感知 flow/runtime 细节。

本计划的目标不是继续搬目录，而是把这两处泄漏收敛为显式 Port，并用测试把边界固定下来。完成后，读者应能看到以下可见结果：

- `src/game/core/player/` 不再直接 `require` `src/game/systems/*`。
- `src/game/systems/endgame/bankruptcy.lua` 不再直接访问 `game.gameplay_loop_ports`。
- `tests/internal/dep_rules.lua` 能阻止上述两类倒退。
- 现有破产、医院扣费、地块清空、反馈事件回归测试仍通过。

## 进度

- [x] (2026-03-07 00:00Z) 已完成研究快照，确认主要问题集中在 `location_ops` 反向依赖与 `bankruptcy.lua` 对 `game.gameplay_loop_ports` 的对象耦合。
- [x] (2026-03-07 09:25Z) 已新增 `src/game/ports/bankruptcy_feedback_port.lua`，并在 `src/game/core/runtime/game.lua` 提供默认 no-op 实现。
- [x] (2026-03-07 09:25Z) `src/game/systems/endgame/bankruptcy.lua` 已改为通过 `bankruptcy_feedback_port` 发地块清空反馈，不再读取 `game.gameplay_loop_ports`。
- [x] (2026-03-07 09:25Z) `src/game/core/player/state_ops/location_ops.lua` 已改为通过 `src/game/ports/bankruptcy_port.lua` 触发破产，移除对 `systems/endgame/bankruptcy.lua` 的直接依赖。
- [x] (2026-03-07 09:25Z) 已补 `tests/internal/dep_rules.lua` 与回归/契约测试，覆盖 `core/player ↛ systems` 和 `systems ↛ game.gameplay_loop_ports`；同时顺手清理 `vehicle_ops.lua`、`status_ops.lua` 对 `systems/vehicle/vehicle_feature.lua` 的旧依赖。
- [x] (2026-03-07 09:25Z) 已运行针对性回归与全量回归，并把结果回写到本计划。

## 意外与发现

- 观察：`src/game/core/runtime/` 已经收窄为聚合根与装配，破产与胜负规则已迁到 `src/game/systems/endgame/`，目录级重构阶段基本完成。
  证据：`src/game/core/runtime/game.lua` 现在绑定 `src.game.systems.endgame.game_victory`；`src/game/runtime/bankruptcy_port_adapter.lua` 指向 `src.game.systems.endgame.bankruptcy`。
- 观察：当前最大风险不是继续“放错目录”，而是 `game` 对象上的临时字段变成跨层隐式接口。
  证据：`src/game/systems/endgame/bankruptcy.lua` 的 `_notify_tiles_cleared()` 直接读取 `game.gameplay_loop_ports.state.on_bankruptcy_tiles_cleared`。
- 观察：现有 `tests/internal/dep_rules.lua` 擅长拦截 `require(...)` 与部分 legacy 字段，但对对象字段耦合的覆盖不足。
  证据：研究快照与当前规则中没有针对 `game.gameplay_loop_ports` 的禁止项。
- 观察：新增 `core/player ↛ systems` 规则后，立即暴露出 `vehicle_ops.lua` 与 `status_ops.lua` 两条既有依赖，不仅是 `location_ops.lua` 一处。
  证据：第一次运行 `tests/internal/dep_rules.lua` 时先后报出 `src/game/core/player/state_ops/vehicle_ops.lua` 与 `src/game/core/player/state_ops/status_ops.lua` 依赖 `src.game.systems.vehicle.vehicle_feature`；两处现已改为直接依赖 `src.core.config.feature_toggles`。
- 观察：本轮不需要新增新的 presentation 适配模块，只需让 `gameplay_loop.set_game()` 把 `ports.state.on_bankruptcy_tiles_cleared` 包装成 `game.bankruptcy_feedback_port` 即可。
  证据：新增的 `_test_gameplay_loop_set_game_installs_bankruptcy_feedback_port` 已证明 `state` 端口回调仍然被转发。

## 决策日志

- 决策：本轮优先修两处真实边界泄漏，不再做新的目录搬迁。
  理由：研究已确认目录语义基本稳定，继续搬目录收益低于修对象级/依赖级泄漏。
  日期/作者：2026-03-07 / Codex
- 决策：优先采用“Port 增量隔离”，而不是大范围重写 `gameplay_loop` 或 `player/state_ops`。
  理由：这是最小可落地路径，能在不动大框架的前提下切断关键反向依赖。
  日期/作者：2026-03-07 / Codex
- 决策：把边界收口与 dep rules/contract tests 绑定推进，不接受“只改实现、不加护栏”。
  理由：当前问题的本质是边界容易回流，仅靠目录命名无法防守。
  日期/作者：2026-03-07 / Codex
- 决策：本轮复用 `game` 上的新 `bankruptcy_feedback_port`，而不是扩展 `tile_feedback_port`。
  理由：破产清空地块是终局反馈，不等同于单地块升级反馈；单独 Port 语义更清晰，也能避免把 `tile_feedback_port` 职责继续做大。
  日期/作者：2026-03-07 / Codex
- 决策：把 `core/player ↛ systems` 规则按目录整体收紧，并顺手清理新暴露出来的两条既有载具依赖。
  理由：若只为 `location_ops.lua` 开特判，会保留同类问题并削弱规则价值；而 `vehicle_feature` 依赖很薄，清理成本低。
  日期/作者：2026-03-07 / Codex

## 结果与复盘

本轮计划已完成，结果如下：

1. `src/game/systems/endgame/bankruptcy.lua` 不再直接读取 `game.gameplay_loop_ports`，而是只依赖新增的 `src/game/ports/bankruptcy_feedback_port.lua`。
2. `src/game/core/player/state_ops/location_ops.lua` 不再直接依赖 `src/game/systems/endgame/bankruptcy.lua`，而是通过 `src/game/ports/bankruptcy_port.lua` 触发破产。
3. `tests/internal/dep_rules.lua` 已新增两条护栏：`core/player ↛ systems`、`systems ↛ game.gameplay_loop_ports`。
4. 在收紧 `core/player ↛ systems` 之后，顺手清理了 `src/game/core/player/state_ops/vehicle_ops.lua` 与 `src/game/core/player/state_ops/status_ops.lua` 对 `src.game.systems.vehicle.vehicle_feature` 的既有依赖。

验证结果：

- 运行针对性回归：`All regression checks passed (25)`，随后输出 `dep_rules ok`。
- 运行全量回归：`lua tests/regression.lua` 通过，输出 `All regression checks passed (377)`、`dep_rules ok`、`tick ok`、`forbidden_globals ok`。

缺口与后续：

- 本轮没有继续拆 `presentation_ports.state.on_bankruptcy_tiles_cleared` 这条展示适配实现，因为它已经位于外层 adapter，且当前不再被 systems 直接感知。
- 仍可继续关注 `game` 对象上是否还有其他临时字段被内层规则当作隐式接口，但本轮计划里点名的关键泄漏已经被切断。

## 背景与导读

这份计划面向第一次接触仓库的实现者。下面按职责列出与任务直接相关的模块。

### 关键业务与装配文件

- `src/game/core/player/state_ops/location_ops.lua`
  - 玩家进入医院、深山、位置相关状态操作。
  - 当前在医院扣费失败时直接调用 `src.game.systems.endgame.bankruptcy`，是本计划要移除的反向依赖。
- `src/game/systems/endgame/bankruptcy.lua`
  - 负责破产结算：清空地块、清空库存、发破产弹窗、发反馈事件、淘汰玩家、触发生命/失败表现。
  - 当前通过 `game.gameplay_loop_ports` 发“地块已清空”通知，是本计划要隔离的对象耦合。
- `src/game/systems/endgame/game_victory.lua`
  - 负责胜负判定；本轮不计划大改，只作为终局规则上下文参考。
- `src/game/ports/bankruptcy_port.lua`
  - 当前已经存在的玩法 Port 契约；本计划将优先复用它，而不是为 `location_ops` 另开直连路径。
- `src/game/runtime/bankruptcy_port_adapter.lua`
  - 当前把 `bankruptcy_port` 接到 `src.game.systems.endgame.bankruptcy`。
- `src/game/flow/turn/gameplay_loop.lua`
  - 负责运行时注入 port 与 loop 级装配；若新增 `bankruptcy_feedback_port`，大概率要在这里注入或覆盖。
- `src/game/core/runtime/composition_root.lua`
  - 负责 game 初始装配与默认 adapter；若新增默认空实现，这里可能是默认安装点。

### 关键测试与文档文件

- `tests/suites/gameplay.lua`
  - 已覆盖破产、地块清空、医院/强制支付、角色死亡/失败表现等路径，是本计划的主要回归依据。
- `tests/TestSupport.lua`
  - 统一测试入口；若 Port 注入方式变化，需要同步更新测试构造。
- `tests/internal/dep_rules.lua`
  - 当前路径级边界守卫，需要在这里补充新的禁止规则。
- `tests/suites/usecase_boundary_contract.lua`
  - 当前验证 output port 与 use case 边界；若引入新的反馈 Port，应视情况增加契约测试。
- `docs/architecture/boundaries.md`
  - 目录语义文档，若本轮引入新的稳定 Port，需要同步说明“systems 不再读取 gameplay_loop_ports”。
- `docs/architecture/layer-model.md`
  - 7 组件分层模型；若 Port 链条发生变化，应把新 Port 放进示意。

### 术语说明

- **state**：这里主要指 `src/game/core/player/` 一侧的状态与状态操作，不是 UI state。
- **systems**：`src/game/systems/` 中的玩法规则模块。
- **Port**：稳定边界契约。内层只依赖 Port，不依赖具体注入方或外层字段组织方式。
- **对象级耦合**：没有 `require` 错路径，但通过运行时对象字段名知道外层怎么组织数据，比如直接读 `game.gameplay_loop_ports`。

## 里程碑

### 里程碑 1：终局反馈先被端口化

范围是把 `bankruptcy.lua` 对 `game.gameplay_loop_ports` 的直接读取换成稳定 Port。完成后，代码库会新增一个之前没有的、显式可替换的破产反馈边界，终局规则不再知道 gameplay loop 的字段组织。实施时应至少运行与破产相关的 gameplay 用例和边界契约。验收信号是：`src/game/systems/endgame/bankruptcy.lua` 中不再出现 `game.gameplay_loop_ports`，且破产清空地块后的反馈仍然被现有 UI / state 路径收到。

### 里程碑 2：state 不再直连 systems

范围是把 `location_ops.lua` 从直接 `require("src.game.systems.endgame.bankruptcy")` 改为通过 `src/game/ports/bankruptcy_port.lua` 触发破产。完成后，`src/game/core/player/` 不再反向依赖 `src/game/systems/`。实施时应至少运行医院扣费失败、破产弹窗、玩家淘汰三类路径。验收信号是：`tests/internal/dep_rules.lua` 可以禁止 `core/player -> systems` 直接依赖，且相关 gameplay 测试通过。

### 里程碑 3：护栏固化并形成可回归证明

范围是补 dep rules、contract tests、必要文档。完成后，下一位开发者即使不了解这次重构，也会在引入同类倒退时立即被测试拦住。实施时应运行针对性回归，再视情况跑 `lua tests/regression.lua`。验收信号是：新增规则命中风险路径、现有回归不红、文档说明与实现一致。

## 工作计划

先从最窄的泄漏点下手：在 `src/game/systems/endgame/bankruptcy.lua` 周围建立稳定反馈 Port，而不是直接修改更多业务流程。第一步阅读 `bankruptcy.lua` 的 `_notify_tiles_cleared()`、`src/game/flow/turn/gameplay_loop.lua` 中现有的 `gameplay_loop_ports` 组织方式，以及 `src/presentation/adapter/presentation_ports/state_ports.lua` 对 `on_bankruptcy_tiles_cleared` 的消费路径，明确最小需要暴露的函数签名。

接着在 `src/game/ports/` 或现有反馈 port 体系中新增/扩展稳定契约，并在 `src/game/core/runtime/composition_root.lua` 提供默认空实现，在 `src/game/flow/turn/gameplay_loop.lua` 提供运行时覆盖实现。之后修改 `src/game/systems/endgame/bankruptcy.lua`，让它只通过该 Port 发通知。此时先补针对 `bankruptcy.lua` 的契约测试与 gameplay 测试，确认“清空地块后的反馈链条”没有断。

第二阶段再处理 `src/game/core/player/state_ops/location_ops.lua`。修改时只做最小必要变更：删除对 `src.game.systems.endgame.bankruptcy` 的 `require`，改为调用 `src/game/ports/bankruptcy_port.lua`。如果现有 `bankruptcy_port` 已足够，则不新增额外接口；如果调用语义不够清楚，再微调 Port 契约，但不把医院逻辑整块搬进 use case。修改后优先复跑医院扣费失败与破产相关用例。

最后统一补强护栏：在 `tests/internal/dep_rules.lua` 中新增 `src/game/core/player/` 不能直接 require `src/game/systems/*` 的规则，并为 `src/game/systems/` 新增禁止读取 `game.gameplay_loop_ports` 的规则。必要时在 `tests/suites/usecase_boundary_contract.lua` 或新测试中增加 Port 默认行为与覆盖优先级验证。若文档中的 Port 注入示意已过时，同步更新 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md`。

## 具体步骤

以下命令默认在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行。

1. 清点当前调用链与消费方。

   ```bash
   rg -n "gameplay_loop_ports|on_bankruptcy_tiles_cleared|bankruptcy_port|systems.endgame.bankruptcy|location_ops" src tests
   ```

   预期：能看到 `location_ops.lua`、`bankruptcy.lua`、`bankruptcy_port.lua`、`bankruptcy_port_adapter.lua`、`gameplay_loop.lua`、`presentation_ports/state_ports.lua` 的命中。

2. 设计并落地稳定反馈 Port。

   ```bash
   # 编辑相关文件
   # - src/game/ports/<new_or_extended_port>.lua
   # - src/game/core/runtime/composition_root.lua
   # - src/game/flow/turn/gameplay_loop.lua
   # - src/game/systems/endgame/bankruptcy.lua
   ```

   预期：`bankruptcy.lua` 不再出现 `game.gameplay_loop_ports`。

3. 处理 `location_ops` 反向依赖。

   ```bash
   # 编辑相关文件
   # - src/game/core/player/state_ops/location_ops.lua
   # - src/game/ports/bankruptcy_port.lua (若需微调)
   ```

   预期：`location_ops.lua` 不再 `require("src.game.systems.endgame.bankruptcy")`。

4. 补 dep rules 与契约测试。

   ```bash
   # 编辑相关文件
   # - tests/internal/dep_rules.lua
   # - tests/suites/usecase_boundary_contract.lua 或新增相关测试
   # - tests/suites/gameplay.lua（如需）
   ```

   预期：新增规则能表达两条禁止边界，相关测试文件可独立运行。

5. 运行针对性验证。

   ```bash
   lua - <<'LUA'
   package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'
   local harness = require('TestHarness')
   harness.run_all({
     require('gameplay_core'),
     require('architecture_guard_contract'),
     require('usecase_boundary_contract'),
   })
   dofile('tests/internal/dep_rules.lua')
   LUA
   ```

   预期：输出 `All regression checks passed (...)` 且 `dep_rules ok`。

6. 如针对性验证稳定，再跑全量回归。

   ```bash
   lua tests/regression.lua
   ```

   预期：全量回归通过；若不是本轮改动引入的问题，需要记录在“意外与发现”，但不扩展修 unrelated 问题。

## 验证与验收

验收必须覆盖以下四类结果：

1. **实现边界**
   - `src/game/systems/endgame/bankruptcy.lua` 不再直接读取 `game.gameplay_loop_ports`。
   - `src/game/core/player/state_ops/location_ops.lua` 不再直接 require `src/game/systems/*`。

2. **Port 边界**
   - 新增/调整后的 Port 在无实现时有安全默认值。
   - `gameplay_loop` 或 `composition_root` 的注入优先级有测试覆盖。

3. **回归行为**
   - 医院扣费失败仍会触发破产。
   - 破产仍会清空地块、清空库存、淘汰玩家、发反馈事件、保持现有 UI/状态同步。

4. **护栏固定**
   - `tests/internal/dep_rules.lua` 能拦截 `core/player -> systems` 的直接依赖。
   - `tests/internal/dep_rules.lua` 或等价测试能拦截 `systems -> game.gameplay_loop_ports` 的对象字段耦合。

建议采用以下验收表述：

- 运行上文第 5 步命令，预期针对性回归全部通过；新/调整测试在变更前失败、变更后通过。
- 运行 `lua tests/regression.lua`，预期全量回归通过；如果出现历史既存失败，需要在“意外与发现”记录，不把 unrelated 修复混入本计划。

## 可重复性与恢复

本计划适合按里程碑重复执行。推荐顺序是“先加 Port 与默认实现，再改消费者，再删旧耦合”。不要反过来先删旧路径，否则容易在中间态打断回归。

若某一步失败，按以下原则恢复：

- Port 设计失败：回退新 Port 及其注入点，保留现有 `bankruptcy.lua` 逻辑不动。
- `location_ops` 改造失败：仅回退 `location_ops.lua` 与相关 Port 微调，不回退已稳定的反馈 Port。
- dep rules/测试失败：先保留实现修复，再单独调整测试表达，避免把真正已修复的边界问题回滚掉。

完成后应保持工作区整洁，避免把分析脚本、统计产物或无关技能文档混入同一提交。

## 产物与备注

本计划实施完成后，预期最小产物如下：

    src/game/ports/bankruptcy_port.lua                  # 继续承载“触发破产”稳定契约
    src/game/ports/<bankruptcy_feedback_port>.lua       # 若新增，则承载“地块清空反馈”稳定契约
    src/game/systems/endgame/bankruptcy.lua             # 不再读取 game.gameplay_loop_ports
    src/game/core/player/state_ops/location_ops.lua     # 不再直接 require systems/endgame
    tests/internal/dep_rules.lua                        # 新增边界禁止规则
    tests/suites/usecase_boundary_contract.lua          # 新增/补强 Port 契约测试
    tests/suites/gameplay.lua                           # 补或调整破产相关回归

如果最终决定不单独新增 `bankruptcy_feedback_port.lua`，也必须在代码与文档里明确“复用哪一个现有 port，以及为什么它足够稳定”。

## 接口与依赖

本轮优先复用现有接口，只有在现有接口无法表达稳定边界时才新增最小接口。

### 已有接口

在 `src/game/ports/bankruptcy_port.lua` 中应继续维持：

```lua
function bankruptcy_port.eliminate(game, player, opts)
end
```

在 `src/game/runtime/bankruptcy_port_adapter.lua` 中应继续维持：

```lua
function adapter.build()
  return {
    eliminate = function(game, player, opts)
      -- adapter 到具体破产实现
    end,
  }
end
```

### 建议新增的接口（若现有体系无法承载）

在 `src/game/ports/bankruptcy_feedback_port.lua` 中定义：

```lua
function bankruptcy_feedback_port.on_tiles_cleared(game, player, owned_tile_ids)
end
```

对应默认实现应为 no-op，运行时实现可由 `src/game/flow/turn/gameplay_loop.lua` 或展示侧 adapter 注入。关键约束是：`src/game/systems/endgame/bankruptcy.lua` 只能依赖这个稳定函数签名，不能依赖 `gameplay_loop_ports` 的字段组织。

### 允许依赖与禁止依赖

- 允许：`src/game/core/player/state_ops/location_ops.lua` → `src/game/ports/bankruptcy_port.lua`
- 允许：`src/game/runtime/bankruptcy_port_adapter.lua` → `src/game/systems/endgame/bankruptcy.lua`
- 允许：`src/game/flow/turn/gameplay_loop.lua` / `src/game/core/runtime/composition_root.lua` 安装 Port 实现
- 禁止：`src/game/core/player/*` → `src/game/systems/*`
- 禁止：`src/game/systems/*` 直接读取 `game.gameplay_loop_ports`

---

更新说明：2026-03-07 基于 `.agents/research.md` 重写本计划，废弃旧的 snake_case 迁移计划内容。原因是仓库当前的主要工作已从目录搬迁转向边界收口，需要一份围绕终局 Port、依赖方向与回归验证的可执行计划。

更新说明：2026-03-07 09:25Z 已按本计划完成终局反馈 Port 化、`location_ops` 去直连、dep rules 收紧、既有载具依赖清理，并记录回归证据。原因是本轮实施已完成，计划必须同步反映真实状态与验证结果。
