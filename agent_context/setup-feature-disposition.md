# setup.feature 处置：register（非删除）+ 真闭环（setup-feature-disposition）

specifier → coder。源自 ADR 0017 D4（孤儿 `features/game/setup.feature` 处置）。

## 裁定：register，不删除

`features/game/setup.feature`（功能「开局初始化」，4 场景）确认有产品价值——与 ADR 0011 在范围内对齐项（开局玩家数 / 单人补 3 个电脑 / 初始金币 / 卡槽）一一对应，且有真 src 支撑。按 D4「有价值 → 入 acceptance_features.lua 并写经真闭环 handler」。

**孤儿现状**（确认）：无 `tools/acceptance/steps/setup.lua`、不在 `tools/acceptance/acceptance_features.lua`（22 项 registry 无它）、无 harness 引用。feature 顶部 manifest 结果是早期独立跑的陈旧残留——它从未在当前套件跑过。

## 真 src 支撑（已核）

| 场景 | 真入口/真源 | 可测性 |
|---|---|---|
| 角色开局状态一致（出生起点 / 金币100000 / 地块0 / 道具0 / 卡槽上限5） | `game_driver.new_game`（经 `compose_game.new_game`）建真游戏读真 player 状态；100000=`src/config/content/constants.lua:starting_cash`、5=`constants.lua:inventory_slots`（**D3 单一真源，断言读 constants，勿硬编码 100000/5**） | **纯净可测**，无 host 耦合 |
| 报名人数→行动角色数 / 单人补足3电脑 / 拒绝<1或>4 | `src/app/roster.lua`（:233 调 `composition_root.new_game(resolve_game_opts{...})`）；含 `_pick_synthetic_unit_keys`/`_add_synthetic_roles_to_roster`(AI 补足)、`max_player_count=4`、`_resolve_roles`(host 真角色) | **host 耦合**：roster 从 host 拉真角色 + `runtime_refs.synthetic_ai` 补 AI |

## 架构裁定：B — 重框 feature 匹配现 src（已裁 2026-05-31，ADR 0017 D4 附录）

coder 读真 src 后升级：`roster.lua`（`max_player_count=4` 硬编码、`_build_startup_roster` 补 AI 到 4、`_warn_if_roles_truncated` 仅 warn）**恒填 4 槽、无 reject、无「报名人数」输入**，与初版契约「roster 支撑全部场景」对场景3（2-4 按原数不补）、场景4（拒绝 0/5）为假。

升级用户裁定（产品价值 + 未批 ADR 0011 + 宿主四槽容忍）：**产品行为以现 src 为准——恒 4 人局（真人不足补 AI）、永不拒绝**。不改 `roster.lua`、不动初始化语义、不触宿主四槽。

- 取 B，不取 A（抽纯规则 + reject + 2-3 人，兑现未批 ADR 0011，搁置）、不取 C（无需拆分）。
- specifier lane：register + 重框场景使其与「恒 4 槽」自洽；**删掉**「2-4 按原数不补」与「拒绝开局」。

## 重框后的场景（specifier 交付，匹配现 src）

替换 `features/game/setup.feature` 现有 4 场景。参数保留对 Gherkin 变异有效者（报名人数 / 电脑数）；行动角色数恒 4 不再参数化。

```gherkin
功能: 开局初始化

  背景:
    假如 游戏配置为标准大富翁模式

  场景大纲: 报名真人不足时补足电脑角色到4人
    假如 本局报名真人玩家数为<报名人数>
    当 游戏初始化
    那么 本局行动角色数为4
    并且 其中电脑角色数为<电脑数>
    并且 游戏允许开始

  例子:
    | 报名人数 | 电脑数 |
    | 0        | 4      |
    | 1        | 3      |
    | 2        | 2      |
    | 3        | 1      |
    | 4        | 0      |

  场景: 报名真人超过4人时截断为4个行动角色
    假如 本局报名真人玩家数为5
    当 游戏初始化
    那么 本局行动角色数为4
    并且 游戏允许开始

  场景: 全部4个开局角色状态一致
    当 游戏初始化为标准四人局
    那么 每名角色出生在起点
    并且 每名角色初始金币为100000
    并且 每名角色初始地块数为0
    并且 每名角色初始道具数为0
    并且 每名角色道具卡槽上限为5
```

## 真闭环形态（coder 实现）

- 入 `acceptance_features.lua` 加一行（`features/game/setup.feature` → `setup_acceptance_spec.lua`），新建 `tools/acceptance/steps/setup.lua`。**原子落地**：register + 步骤实现同提交，避免 main `make acceptance` 中途红。
- 所有场景经 `game_driver.new_game`（真 `compose_game`）+ `roster.lua` 真装配 + `runtime_ports` 注入真角色 mock（模拟报名 N 个真角色）驱动；断言读 player 真状态 / `constants.lua` 单源（金币 100000、卡槽 5，**勿硬编码**）。
- 不落 fixture、不重实现 roster 规则（D1/D5）。「电脑角色数」读真装配后的合成 AI 角色计数。

## ADR 0011 张力

ADR 0011 D1「开局玩家数 / 单人补 3 电脑」与本裁定（恒 4 / 真人不足补 AI / 不 reject）是设计 vs 实现两套；ADR 0011 仍 proposed，待用户整体 review 一并裁。本次以现 src 为准。

## 反证 & manifest

- 反证：重接后对 `roster.lua` 补 AI / 人数校验分支、`game_state` 初始化关键差分变异由 survivor 转 killed（coder/architect 跑变异，specifier 不跑）。
- feature 顶部 acceptance-mutation-manifest 不手改，由 gherkin-mutator 刷新。
- 新 feature 入 registry 后 `make acceptance` 重生成 gitignored 生成物（ADR 0015）。
