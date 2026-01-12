# Effect 系统审查与落地计划（大富翁）

> 目的：把“落地/抽卡/奖励/惩罚/交易/建房”等事件统一收敛到 Effect 容器，避免在 `turn/*`、`services/*` 中分散的 if-else，提升可扩展性与可维护性。

## 1. 范围与现状入口

当前与“落地结算/效果”最相关的文件：

- `src/gameplay/effect.lua`：Effect 容器（list/resolve）。
- `src/gameplay/effects/land.lua`：落地相关效果定义（租金/税/买地/加盖/起点奖励等）。
- `src/gameplay/turn/land.lua`：回合阶段落地入口。
- `src/gameplay/land_resolver.lua`：落地效果执行（mandatory/optional + Choice）。
- `src/gameplay/choice.lua` / `src/gameplay/choice_resolver.lua`：选择弹窗与选择结果落地。
- `src/gameplay/services/tile_service.lua`：医院/深山/黑市/机会/道具/地雷等“格子事件”。
- `src/gameplay/services/chance_service.lua`：机会卡抽取与结算（包含二次移动与再次落地结算）。

## 2. 现状审查（与三层 Effect 的对应关系）

### 2.1 容器层（`src/gameplay/effect.lua`）

- 已有：
  - **扫描/过滤**：`Effect.list(effect_defs, ctx)` 基于 `can_apply` 过滤。
  - **执行顺序**：`Effect.resolve` 先 mandatory，后 optional（可传 `choose_fn`）。
- 不足：
  - `can_apply` 的 `reason` 没有进入扫描结果，也没有用于 UI 展示/禁用态。
  - `apply` 不返回 `events[]`，也没有统一的“可回放事件”概念。
  - `Effect.list` 内部直接调用 `eff.can_apply(ctx)`，**不接收/传播 reason**，且接口返回形式不统一。

### 2.2 落地效果定义（`src/gameplay/effects/land.lua`）

- 已有：落地的部分规则已经 Effect 化：
  - mandatory：`pay_rent` / `tax` / `start_reward`
  - optional：`buy_land` / `upgrade_land`
- 不足：
  - `apply` 直接修改对象并写日志（命令式），没有 `events[]`。
  - 一些“落地相关事件”仍散落在 `TileService.resolve`、`ChanceService` 的 handler 中，不在一个容器内统一排序与统一调度。

### 2.3 落地入口（`src/gameplay/turn/land.lua`）

- 当前顺序：
  1) `TileService.resolve(...)` 处理 tile 事件（机会/道具/黑市/医院/深山/地雷/路过偷窃等）
  2) `LandResolver.resolve(...)` 再处理 land_effects（租金/税/买地/加盖等）

问题：落地结算被拆成“两套体系”，无法用一套 Effect 顺序规则对齐全链路。

### 2.4 可选效果选择（`src/gameplay/land_resolver.lua` + `src/gameplay/choice_resolver.lua`）

- 已有：将 optional effects 通过 `Choice.open` 暴露给 UI。
- 关键不足：
  - 选择落地时直接 `target_eff.apply(ctx)`，**没有二次 `can_apply` 校验**（状态变化后可能不该执行）。
  - `choice_resolver.lua` 构造的 ctx 不包含 `move_result` 等字段，ctx 约定不统一。

## 3. 对照“三层 Effect”差距清单

> 文档目标三层结构：扫描层 -> 判定层 -> 执行层。

- 扫描层：
  - 需要标准化 `list_available_effects(ctx)`：按 phase/规则开关/上下文输出“可用/不可用 + reason”。
  - 需要让 UI 看到禁用原因（而不是简单过滤掉）。
- 判定层：
  - 需要统一 `can_apply(effect, ctx) -> bool, reason?` 语义并强制执行。
  - 需要在“选择后执行”前进行二次校验（防 stale choice）。
- 执行层：
  - 中长期需要 `apply(effect, ctx) -> events[]`（或至少支持产出 events），用于回放/调试/一致性验证。
  - 需要把“落地全链路事件”（tile events + land events + 抽卡/移动带来的二次落地）逐步收敛到容器调度。

## 4. 落地实施计划（按 PR 拆分，优先行为不变）

### PR1：固化 Effect 管线接口（不改玩法）

目标：把三层接口在工程里“站稳”，先解决 reason/二次校验/ctx 约定。

- 强化 `src/gameplay/effect.lua`：
  - 统一 `can_apply` 返回 `(ok, reason)`；扫描结果保留 `reason`。
  - 扫描结果建议形态：`{ id, label, mandatory, ok, reason, effect }`（UI 可展示禁用理由）。
  - 增加统一执行入口：`Effect.execute(effect, ctx)`（内部二次校验 `can_apply`，失败时返回 reason，且不执行）。
- 固化 ctx 最小字段约定（建议）：
  - `ctx = { game, store, rng, phase, player, tile, move_result }`

验收：可选效果选择后执行路径走二次校验；扫描层可拿到 reason。

### PR2：合并落地入口到“一个容器”（排序可控）

目标：把 `TileService.resolve` 的“格子事件”也纳入落地容器的 mandatory list（先包装，不强拆）。

- 新增一个落地容器（例如 `src/gameplay/effects/landing.lua`）：
  - mandatory：包装 `TileService.resolve` 为一个 effect（保留现有行为）。
  - mandatory：现有 `pay_rent`、`tax`、`start_reward`。
  - optional：`buy_land`、`upgrade_land`。
- `src/gameplay/turn/land.lua`：只调用一次容器 resolve（去掉“两段式” resolve）。
- 处理重复职责：
  - `src/gameplay/land_resolver.lua` 与 `src/gameplay/effect.lua` 职责重叠，应在此 PR 里收敛为单一路径（保留一个）。

验收：落地阶段入口只有一次“扫描→执行→可选选择”的链路；强制效果顺序可在 defs 中明确。

### PR3：Choice 执行统一走 `Effect.execute`（二次校验 + ctx 一致）

目标：避免 stale choice，并让所有选择落地走同一条管线。

- `Choice.open` 的 meta 保存必要定位信息：`{ player_id, tile_id, move_result? , effect_ids? }`。
- `src/gameplay/choice_resolver.lua`：
  - 根据 choice.kind 获取“容器 defs”并按 id 找 effect。
  - 构造标准 ctx，然后调用 `Effect.execute(effect, ctx)`。
  - execute 失败（`ok=false`）时：记录 reason（最简：logger + 跳过）。

验收：可选效果在点击执行前会重新判定；ctx 字段统一。

### PR4：机会卡/道具逐步 Effect 化（可拆多 PR）

目标：减少 `services/*` 中与规则相关的分支，让“事件”回到 effects。

建议顺序：

1) 先将“抽卡并结算”包装为一个 mandatory effect（内部仍调用 `ChanceService`），把入口统一。
2) 再把 `ChanceService` 的 handler table 迁移到 `src/gameplay/effects/chance.lua`：
   - 方案 A：一张卡=一个 effect（可读性更强）。
   - 方案 B：card->effect 工厂（更贴近配置驱动）。

验收：抽卡与结算入口不再散落在 `TileService`/`ChanceService` 的分支中；容器顺序可控。

### PR5（可选/中期）：引入 `events[]`（为回放/复现打基础）

目标：实现“可回放/可复现”的 effect 执行记录。

- `apply(effect, ctx) -> events[]` 逐步推行：
  - 初期允许边改 store 边产 events；
  - 中期迁移到“只产事件，由统一 applier 改 store”。

验收：关键落地效果能产出结构化 events，便于回放与断言。

## 5. 风险与注意点

- stale choice：选择弹窗打开后，状态可能变化（现金/所有权/格子状态），必须二次校验。
- ctx 约定：建议在容器层统一构造 ctx，避免不同调用点遗漏字段（当前 `choice_resolver` 未带 `move_result`）。
- 去重：`Effect.resolve` 与 `LandResolver.resolve` 现在都有“mandatory/optional 分组”逻辑，应收敛为一个权威实现。

## 6. 最小验收清单（每个 PR 都能测）

- 落地阶段不出现行为回归（租金/税/买地/加盖/起点奖励/机会/道具/地雷/路过偷窃）。
- 打开可选行动后，执行前会二次判定 `can_apply`。
- 扫描层能拿到不可用原因（reason），并可用于 UI 展示（哪怕当前 UI 先不展示）。
