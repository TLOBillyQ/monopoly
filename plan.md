# 重构：src/ 扁平化与命名简化

本可执行计划是活文档。实施过程中必须持续更新「进度」、「意外与发现」、「决策日志」、「结果与复盘」。

本仓库不维护 PLANS.md 索引；本文件遵循 `.agents/conventions/planning.md` 的可执行计划规范。

## 目的 / 全局视角

为什么改：`src/` 现有 375 个 Lua 文件，七层 + foundation 边界稳定但层内长出大量「目录已说过的前缀/后缀」。例如 `src/player/actions/state_ops/balance_ops.lua` 这一长串里，`state_ops` 目录已经把"它是 state 操作"说得清清楚楚，文件再加 `_ops` 是噪音；`src/ui/render/widgets/panel_presenter.lua` 同理，目录是 widgets 又强调 panel。这类冗余拉长了 require 字符串、增加了视觉扫描成本，也让命名搜索（`git grep`）出现噪声。

改完后开发者获得的可见行为：
- `git grep` 单 token 命中目标的命中率上升（前缀/后缀让搜索词被重复包裹时干扰多）
- require 字符串短一档，文件树视觉密度更均匀
- `rules/ports/` 把所有规则层 port 收齐，符合 `docs/architecture/boundaries.md` "Port 命名规则"
- `computer/core_agent.lua` 与 `ui/render/action_anim.lua` 这两处「入口文件 + 同名子目录内部」的双重表达统一为 Lua 包风格（`init.lua` 作为入口）

如何看到生效：
1. `lua tools/quality/lint.lua` 退出码 0
2. `busted --run smoke`（或项目默认 profile，见 `.agents/README.md`）通过
3. `tools/quality/arch/run.sh`（如有）或对应 arch_view 检查无新违规
4. 关键命名 `git grep` 反查：例如 `git grep -l "panel_presenter"` 重命名后只命中文档/历史，不命中现役代码

## 进度

- [ ] (T0) 准备：建立 rename 助手脚本与 baseline（lint + busted + arch_view）
- [ ] 批 A — ports 归位（`rules/market/paid_purchase_port` → `rules/ports/paid_purchase`）
- [ ] 批 B — `player/actions/state_ops/*_ops.lua` 去 `_ops` 后缀
- [ ] 批 C — `ui/render/widgets/panel_*.lua` 去 `panel_` 前缀
- [ ] 批 D1 — `ui/state/modal_state.lua` → `ui/state/modal.lua`
- [ ] 批 D2 — `state/runtime_state.lua` → `state/runtime.lua`（45 处调用，单独 PR）
- [ ] 批 E — `turn/waits/await/*_wait.lua` 去 `_wait` 后缀
- [ ] 批 F — rules 子目录命名碰撞修正（item_config / land/board / land/rules / choice_handler_factory）
- [ ] 批 G — `ui/render/` 顶层去前缀（tile_renderer / ui_assets / canvas_render_pipeline）
- [ ] 批 H — entry→init.lua 规范化（computer/core_agent + ui/render/action_anim）
- [ ] 批 I — `ui/render/board_scene.lua` 归位到 `ui/render/board/scene.lua`
- [ ] (T-end) 收尾：跑全质量车道、更新 `docs/architecture/boundaries.md`（如需）、补本计划「结果与复盘」

每批的颗粒度细分进度记在该批的「具体步骤」段下方的子复选框里（实施时新增）。

## 意外与发现

（实施时填）

- 观察：…
  证据：…

## 决策日志

- 决策：保留 `state/{board,player,turn,game}_state.lua` 的 `_state` 后缀  
  理由：四个文件名分别与上层目录 `rules/board/`、`src/player/`、`src/turn/`、以及"游戏根对象"地标语义碰撞；后缀作为 namespace 歧义化仍然产生信息  
  日期/作者：2026-05-04 / 重构发起人

- 决策：foundation/{coordination,identity,events,log,lang,ports}/ 子目录全部保留，即使当前单文件  
  理由：`docs/architecture/boundaries.md` 把 6 个目录列为 foundation 钦定类目，是契约面，不为眼前文件数瘦身  
  日期/作者：2026-05-04 / 重构发起人

- 决策：`ui/coord/ui_*.lua`（ui_runtime / ui_state / ui_events）保留 `ui_` 前缀  
  理由：`ui/coord/runtime.lua` 与 `ui/state/runtime.lua`、`ui/render/runtime_ui.lua` 在 require 字符串上视觉相近，前缀仍承担歧义化作用  
  日期/作者：2026-05-04 / 重构发起人

- 决策：`ui/render/runtime_ui.lua` 不重命名（同上理由 + 32 处调用 churn 大）  
  日期/作者：2026-05-04 / 重构发起人

- 决策：`rules/movement.lua`、`rules/vehicle.lua` 顶层位置保留  
  理由：vehicle 被 `tools/quality/arch/config.json` 明文钉住为 host bridge exception；movement 单文件入子目录是负优化  
  日期/作者：2026-05-04 / 重构发起人

- 决策：批次之间相互独立，每批一个 commit，按需各自成 PR；不强行打包  
  理由：D2 单批触及 45 处调用，独立提交便于回滚定位；批 H 涉及 init.lua 入口调整，单独验证 require 图  
  日期/作者：2026-05-04 / 重构发起人

## 结果与复盘

（完成时填）

## 背景与导读

完全不了解仓库的读者请先读这一节再动手。

### 仓库结构（`src/` 七层 + foundation）

物理目录名 = 逻辑层名 = arch 组件名（`docs/architecture/layer-model.md`）：

```
L1  app                    → src/app/
L2  host                   → src/host/
L3  ui                     → src/ui/
L4  turn                   → src/turn/
L5  player | computer      → src/player/ | src/computer/
L6  rules                  → src/rules/
L7  state | config         → src/state/ | src/config/
─────
foundation（基座）         → src/foundation/   ← 不计入七层；任何层都可依赖；不可依赖任何上层
```

依赖方向严格自上而下；foundation 只接受被依赖。

### 不动的硬约束

- 七层 + foundation 物理目录名（boundaries.md 契约）
- arch_config 显式钉住的 4 个路径，详见 `tools/quality/arch/config.json`：
  - `^src%.host%.global_aliases$`
  - `^src%.config%.content%.runtime_refs$`
  - `^src%.config%.gameplay%.runtime_constants$`
  - `^src%.rules%.vehicle$`
- 抽象层模式：`^src%.foundation%.ports%..+`、`^src%.rules%.ports%..+`
- foundation 子目录（`identity/`、`coordination/`、`events/`、`log/`、`lang/`、`ports/`）全部保留

### 受影响范围

- `src/` 内 375 个 Lua 文件
- `spec/` 内若干测试用 `package.loaded["src.x.y"]` 字符串以及 `require()` 直接调用
- `docs/` 内若干引用具体路径的契约文档（boundaries.md / governance-roadmap.md / subsystems.md）

### 关键术语（必读）

- **port**：契约接口，按 `boundaries.md` "Port 命名规则"，规则层 port 应放在 `src/rules/ports/`
- **abstract_rules**：`tools/quality/arch/config.json` 中按路径模式分类为"抽象"的规则（不算依赖深度）
- **arch_view**：`tools/quality/arch/run.sh` 输出的静态架构扫描，护栏文件 `docs/reports/arch-view.md`
- **busted profile**：项目里有多个测试 profile（smoke / behavior / contract / regression / ...），见 `.busted` 与 `.agents/README.md`

## 工作计划

按散文叙述每批要做什么、为什么这么做、改完后用户能看见什么。具体路径列表与命令在「具体步骤」。

**T0（准备）**：在动任何文件前，把 baseline 跑一遍 —— `lua tools/quality/lint.lua`、`busted --run smoke`、可选 `arch_view`。把输出存到 `tmp/refactor-baseline.txt`，作为后续每批"对照通过即可"的参考。建立一个 rename 助手脚本，统一用"`git mv` + `git grep` 替换" 的两步法，保持每批 commit 干净。

**批 A — ports 归位**。把 `src/rules/market/paid_purchase_port.lua` 整体搬到 `src/rules/ports/paid_purchase.lua`。原文件名带 `_port` 后缀是因为它在 `market/` 下需要这个标签作为类型说明；搬到 `ports/` 后目录已经是 ports，后缀冗余可去。这一改自动让 `^src%.rules%.ports%..+` 抽象规则接管该文件，arch 卫生改善。改完后 `git grep "src.rules.market.paid_purchase_port"` 应该返回 0 行。

**批 B — state_ops 后缀**。`src/player/actions/state_ops/` 下 `balance_ops.lua` / `deity_ops.lua` / `location_ops.lua` / `status_ops.lua` / `vehicle_ops.lua` 全部去掉 `_ops` 后缀。`common.lua` 已经干净不动。模块内部局部变量（如 `local balance_ops = require(...balance_ops)`）会自然变成 `local balance_ops = require(...balance)`，局部名不必动 —— 它仍然准确（balance ops 这个组件，本地化为 balance_ops 没有信息损失，且改少风险）。

**批 C — widgets/panel_ 前缀**。`src/ui/render/widgets/` 4 个文件中 3 个是 `panel_*`，前缀冗余去掉。`turn_effects.lua` 不是 panel，保留原名。如果将来再加 panel 类 widget 数量超过 5 个，再考虑 `widgets/panels/` 子目录。

**批 D1 — ui/state/modal_state**。`ui/state/modal_state.lua` 在 `state/` 子目录里再标 `_state` 是重复，去掉。同目录下 `runtime.lua`、`canvas_store.lua` 已经干净。

**批 D2 — state/runtime_state（独立 PR）**。`state/runtime_state.lua` → `state/runtime.lua`，45 处调用。独立 PR 是因为这一批触及面最大，回滚定位独立比打包好。`state/{game,board,player,turn}_state.lua` 不动（决策日志已说明）。

**批 E — await/*_wait 后缀**。`turn/waits/await/` 下 5 个 `_wait`/`waits` 后缀去掉：action_anim_wait → action_anim、choice_wait → choice、move_anim_wait → move_anim、seconds_wait → seconds、simple_waits → simple。`init.lua`、`debug.lua` 已经干净。`simple_waits` 复数变 `simple` 单数：模块内部仍然导出多个 simple wait 工厂，单数文件名表示"一组 simple 类 wait"在 Lua 模块里很常见（参考 `tables.lua`、`number.lua` 的命名）。

**批 F — rules 子目录命名碰撞**。四个修正：
1. `rules/items/item_config.lua` → `rules/items/config.lua`：`items/` 已带 `item` 信息
2. `rules/land/board.lua` → `rules/land/board_utils.lua`：和顶级 `rules/board/` 撞名，且文件实际暴露的局部变量就是 `board_utils`，命名两端对齐
3. `rules/land/rules.lua` → `rules/land/landing_rules.lua`：`rules/` 层下放 `rules.lua` 是双 "rules"，且和 `landing_defs.lua` 命名风格不一致；改为 `landing_rules` 与 defs 配对
4. `rules/choice_handler_factory.lua` → `rules/choice/handler_factory.lua`：顶层孤儿挪进 `choice/` 框架包

**批 G — ui/render 顶层去前缀**。三个：
1. `tile_renderer.lua` → `tile.lua`：`render/` 已经是 renderer 上下文
2. `ui_assets.lua` → `assets.lua`：在 `ui/render/` 内，`ui_` 前缀冗余
3. `canvas_render_pipeline.lua` → `render_pipeline.lua`：`canvas` 在这里是历史名，文件实际就是渲染管线
`runtime_ui.lua` 不动（决策日志已说明）。

**批 H — entry→init.lua（激进，单独验证）**。两处同构改动：
- `computer/core_agent.lua` → `computer/agent/init.lua`，外部 require 从 `src.computer.core_agent` 改为 `src.computer.agent`
- `ui/render/action_anim.lua` → `ui/render/anim/init.lua`，外部 require 从 `src.ui.render.action_anim` 改为 `src.ui.render.anim`

这是 Lua 包风格的统一：`require("foo.bar")` 默认解析 `foo/bar.lua` 或 `foo/bar/init.lua`。把"入口 + 同名子包内部"的双重表达拍平成一个标准包。**风险点**：要确认入口模块没有循环依赖回内部模块（在第 6 步 lint 前先静态检查 require 图）。

**批 I — board_scene 归位**。`ui/render/board_scene.lua` → `ui/render/board/scene.lua`。`board/` 子目录已存在（anchors、events、init、placement、player_units、startup_render、visual_sync），把 `board_scene` 留在外面是历史包袱。挪进去后视具体内容决定是否最终合并进 `board/init.lua`，本计划只做归位、不合并。

**T-end（收尾）**。所有批做完后：
- 跑完整 busted profile（不仅 smoke）
- 跑 arch_view，对比 baseline 看是否引入新违规
- 检查 `docs/architecture/boundaries.md`、`docs/architecture/governance-roadmap.md`、`docs/architecture/subsystems.md`、`docs/decisions/0001-seven-layer-with-foundation.md` 是否引用过被改名的具体文件路径，必要时同步更新
- 在本计划「结果与复盘」段写最终总结

## 具体步骤

每批的执行模板：
1. `git checkout -b refactor/batch-<letter>` 起新分支
2. 用下文给的 `git mv` 命令搬文件
3. 用下文给的 `find ... | xargs perl -i -pe ...` 命令更新引用（覆盖 `src/`、`spec/`、`docs/`、`tools/`、`tmp/` 之外的所有 `*.lua` 文件）
4. `git grep "<旧 require 字符串>"` 反查是否漏改；预期 0 行（除非命中 docs 历史说明，那需要人工判断保留还是更新）
5. `lua tools/quality/lint.lua`
6. `busted --run smoke`
7. `git add -A && git commit -m "refactor(<scope>): <batch description>"`
8. 把这批的子复选框打勾 + 在「意外与发现」写入任何非预期

### 通用 rename 命令模板

把要改的字符串叫 `OLD` 和 `NEW`（点号在 perl 正则里要转义）。基本形式：

```
# 1) 文件搬运
git mv src/<old/path>.lua src/<new/path>.lua

# 2) 替换所有 .lua 引用（限定 src/ 与 spec/ 范围；如有 tools 引用再扩）
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.<old\.escaped\.path>\b/src.<new.path>/g'

# 3) 反查
git grep -F "src.<old.path>"   # 应返回 0 行
```

> 注意：上面的 `\b` 在某些 require 字符串场景不够强。如果旧路径是某个新路径的前缀（仅批 H 出现：`src.computer.agent` 是 `src.computer.agent.action` 的前缀），改用带引号的精确匹配：
>
> ```
> perl -i -pe 's/(["\047])src\.computer\.core_agent\1/$1src.computer.agent$1/g'
> ```
>
> （`\047` 是单引号 `'`，避开 shell 转义。）

### 批 A — ports 归位

文件改动：

- `src/rules/market/paid_purchase_port.lua` → `src/rules/ports/paid_purchase.lua`（7 处调用）

命令：

```
git mv src/rules/market/paid_purchase_port.lua src/rules/ports/paid_purchase.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.rules\.market\.paid_purchase_port\b/src.rules.ports.paid_purchase/g'
git grep -F "src.rules.market.paid_purchase_port"   # 期望 0
```

完成后跑 lint + smoke。**额外检查**：`tools/quality/arch/config.json` 是否需要更新 abstract_rules 之外的任何 component_rules 例外（按 grep 确认）；boundaries.md "Port 命名规则" 段是否需要补 paid_purchase 的位置说明（视具体行文判断）。

### 批 B — state_ops 后缀

文件改动（5 个文件）：

- `src/player/actions/state_ops/balance_ops.lua` → `balance.lua`（2）
- `src/player/actions/state_ops/deity_ops.lua` → `deity.lua`（4）
- `src/player/actions/state_ops/location_ops.lua` → `location.lua`（1）
- `src/player/actions/state_ops/status_ops.lua` → `status.lua`（2）
- `src/player/actions/state_ops/vehicle_ops.lua` → `vehicle.lua`（1）

命令：

```
cd src/player/actions/state_ops
for f in balance deity location status vehicle; do
  git mv "${f}_ops.lua" "${f}.lua"
done
cd -

for f in balance deity location status vehicle; do
  git ls-files 'src/*.lua' 'spec/*.lua' \
    | xargs perl -i -pe "s/\bsrc\.player\.actions\.state_ops\.${f}_ops\b/src.player.actions.state_ops.${f}/g"
done

# 反查
for f in balance deity location status vehicle; do
  git grep -F "src.player.actions.state_ops.${f}_ops" || true
done   # 期望全部 0 行
```

### 批 C — widgets/panel_ 前缀

文件改动（3 个文件）：

- `src/ui/render/widgets/panel_cash_delta.lua` → `cash_delta.lua`（1）
- `src/ui/render/widgets/panel_player_slots.lua` → `player_slots.lua`（2）
- `src/ui/render/widgets/panel_presenter.lua` → `presenter.lua`（4）

命令：

```
cd src/ui/render/widgets
for pair in "panel_cash_delta:cash_delta" "panel_player_slots:player_slots" "panel_presenter:presenter"; do
  old="${pair%%:*}"; new="${pair##*:}"
  git mv "${old}.lua" "${new}.lua"
done
cd -

for pair in "panel_cash_delta:cash_delta" "panel_player_slots:player_slots" "panel_presenter:presenter"; do
  old="${pair%%:*}"; new="${pair##*:}"
  git ls-files 'src/*.lua' 'spec/*.lua' \
    | xargs perl -i -pe "s/\bsrc\.ui\.render\.widgets\.${old}\b/src.ui.render.widgets.${new}/g"
done
```

### 批 D1 — ui/state/modal_state

```
git mv src/ui/state/modal_state.lua src/ui/state/modal.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.ui\.state\.modal_state\b/src.ui.state.modal/g'
git grep -F "src.ui.state.modal_state"   # 期望 0
```

### 批 D2 — state/runtime_state（独立 PR）

最大单批，45 处调用。命令本身和其他批一样简单，但要单独成 PR：

```
git checkout -b refactor/batch-d2-runtime-state
git mv src/state/runtime_state.lua src/state/runtime.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.state\.runtime_state\b/src.state.runtime/g'
git grep -F "src.state.runtime_state"   # 期望 0
```

完成后跑完整 busted profile（不仅 smoke），因为 runtime_state 出现频率高，破坏面也广。

### 批 E — await/*_wait 后缀

文件改动（5 个）：

- `action_anim_wait.lua` → `action_anim.lua`（3）
- `choice_wait.lua` → `choice.lua`（2）
- `move_anim_wait.lua` → `move_anim.lua`（1）
- `seconds_wait.lua` → `seconds.lua`（1）
- `simple_waits.lua` → `simple.lua`（2）

命令：

```
cd src/turn/waits/await
for pair in "action_anim_wait:action_anim" "choice_wait:choice" "move_anim_wait:move_anim" "seconds_wait:seconds" "simple_waits:simple"; do
  old="${pair%%:*}"; new="${pair##*:}"
  git mv "${old}.lua" "${new}.lua"
done
cd -

for pair in "action_anim_wait:action_anim" "choice_wait:choice" "move_anim_wait:move_anim" "seconds_wait:seconds" "simple_waits:simple"; do
  old="${pair%%:*}"; new="${pair##*:}"
  git ls-files 'src/*.lua' 'spec/*.lua' \
    | xargs perl -i -pe "s/\bsrc\.turn\.waits\.await\.${old}\b/src.turn.waits.await.${new}/g"
done
```

### 批 F — rules 子目录命名碰撞

四步独立改动，建议同一 commit。

**F1 `rules/items/item_config` → `rules/items/config`（3 处）**

```
git mv src/rules/items/item_config.lua src/rules/items/config.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.rules\.items\.item_config\b/src.rules.items.config/g'
```

**F2 `rules/land/board` → `rules/land/board_utils`（4 处）**

```
git mv src/rules/land/board.lua src/rules/land/board_utils.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.rules\.land\.board\b/src.rules.land.board_utils/g'
```

⚠️ 反查时注意 `src.rules.land.board_query` 等可能存在的兄弟模块：以 `\b` 做单词边界已经能避免误伤；改完跑一遍 `git grep -F "src.rules.land.board"`，确认仅命中新名字（`src.rules.land.board_utils`），且没有遗漏的旧裸名。

**F3 `rules/land/rules` → `rules/land/landing_rules`（5 处）**

```
git mv src/rules/land/rules.lua src/rules/land/landing_rules.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.rules\.land\.rules\b/src.rules.land.landing_rules/g'
```

**F4 `rules/choice_handler_factory` → `rules/choice/handler_factory`（3 处）**

```
git mv src/rules/choice_handler_factory.lua src/rules/choice/handler_factory.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.rules\.choice_handler_factory\b/src.rules.choice.handler_factory/g'
```

### 批 G — ui/render 顶层去前缀

```
git mv src/ui/render/tile_renderer.lua src/ui/render/tile.lua
git mv src/ui/render/ui_assets.lua src/ui/render/assets.lua
git mv src/ui/render/canvas_render_pipeline.lua src/ui/render/render_pipeline.lua

git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe '
    s/\bsrc\.ui\.render\.tile_renderer\b/src.ui.render.tile/g;
    s/\bsrc\.ui\.render\.ui_assets\b/src.ui.render.assets/g;
    s/\bsrc\.ui\.render\.canvas_render_pipeline\b/src.ui.render.render_pipeline/g;
  '

git grep -F "src.ui.render.tile_renderer"           # 期望 0
git grep -F "src.ui.render.ui_assets"               # 期望 0
git grep -F "src.ui.render.canvas_render_pipeline"  # 期望 0
```

### 批 H — entry→init.lua（独立 PR，强验证）

**注意**：旧路径是新路径的前缀（`src.computer.agent` 是 `src.computer.agent.action` 等的前缀），普通 `\b` 不够强，必须用带引号的精确匹配。

**H1 `computer/core_agent` → `computer/agent/init`（5 处）**

```
git mv src/computer/core_agent.lua src/computer/agent/init.lua

# 先看入口本身有没有 require 子目录
grep -n "require.*src\.computer\.agent" src/computer/agent/init.lua

# 再批量替换调用方（带引号精确匹配）
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe "s/(['\"])src\.computer\.core_agent\1/\${1}src.computer.agent\${1}/g"

git grep -F "src.computer.core_agent"   # 期望 0
```

⚠️ 检查 `src/computer/agent/init.lua` 内部对 `src.computer.agent.action`、`.decision`、`.path` 的 require 是否依然正确。理论上只是文件位置变化，require 字符串无需改 —— 但要静态读一遍确认没有相对引用。

**H2 `ui/render/action_anim` → `ui/render/anim/init`（10 处）**

```
git mv src/ui/render/action_anim.lua src/ui/render/anim/init.lua

grep -n "require.*src\.ui\.render\.anim" src/ui/render/anim/init.lua

git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe "s/(['\"])src\.ui\.render\.action_anim\1/\${1}src.ui.render.anim\${1}/g"

git grep -F "src.ui.render.action_anim"   # 期望 0
```

⚠️ 同上：`src/ui/render/anim/init.lua` 内部 require `src.ui.render.anim.handlers` 等仍然成立；但要静态确认无循环依赖（init.lua 不应反过来 require 自己同包内会反向引用 init 的子模块）。

**批 H 验证强度提升**：除了 lint + smoke，还跑：
- `busted --run behavior` 至少 movement / animation 相关 spec
- 如果项目有 `tools/quality/arch/run.sh`，必跑
- 启动一次 Eggy 宿主走通最简一回合（开始 → roll → 落地 → 结束），验证动画与 AI 决策两条路径都不挂

### 批 I — board_scene 归位

```
git mv src/ui/render/board_scene.lua src/ui/render/board/scene.lua
git ls-files 'src/*.lua' 'spec/*.lua' \
  | xargs perl -i -pe 's/\bsrc\.ui\.render\.board_scene\b/src.ui.render.board.scene/g'
git grep -F "src.ui.render.board_scene"   # 期望 0
```

⚠️ 改完后看一眼 `src/ui/render/board/init.lua` 暴露面，判断 `board/scene.lua` 是否应被合并进 `init.lua`。本批不合并，保持归位 only；后续如需合并另起一批。

### T0 / T-end 命令

**T0（baseline）**：

```
mkdir -p tmp
lua tools/quality/lint.lua > tmp/refactor-baseline-lint.txt 2>&1
busted --run smoke > tmp/refactor-baseline-smoke.txt 2>&1
# arch_view 视项目实际命令补充
```

**T-end（收尾验证）**：

```
lua tools/quality/lint.lua
busted    # 全部 profile，不带 --run
# arch_view 跑全量
```

并对照 `docs/architecture/boundaries.md`、`governance-roadmap.md`、`subsystems.md`、`decisions/0001-*.md` 做一遍 grep：

```
git grep -F "paid_purchase_port" docs/
git grep -F "core_agent" docs/
git grep -F "action_anim" docs/
git grep -F "board_scene" docs/
git grep -F "tile_renderer\|ui_assets\|canvas_render_pipeline" docs/
git grep -F "panel_cash_delta\|panel_player_slots\|panel_presenter" docs/
git grep -F "balance_ops\|deity_ops\|location_ops\|status_ops\|vehicle_ops" docs/
git grep -F "modal_state\|runtime_state" docs/
git grep -F "_wait\.lua\|simple_waits" docs/
git grep -F "item_config\|choice_handler_factory" docs/
git grep -F "land/rules\|land/board\b" docs/
```

任何命中的 docs 都视语境决定是否更新；历史叙述（如 governance-roadmap 的"曾经叫 X"）保留，活契约（boundaries / 当前 ADR）必须改名。

## 验证与验收

每批做完都要执行：

1. `lua tools/quality/lint.lua` —— 退出码 0
2. `busted --run smoke` —— 全 pass
3. `git grep -F "<旧 require 字符串>"` —— 0 命中（doc 文本语境例外）
4. （批 A、H 额外）`tools/quality/arch/run.sh`（如有，否则查 `docs/reports/arch-view.md` 重生成方式）—— 不引入新违规

T-end 验收（不可省）：

1. `busted` 全 profile pass
2. arch_view 报告与 T0 baseline 对比，违规数仅减不增
3. Eggy 宿主完整跑通一回合（开始 → roll → 落地 → 回合结束 → 至少 1 次 AI 决策）
4. 文档链路（boundaries.md / governance-roadmap.md / subsystems.md / ADR 0001）grep 旧名 0 命中（叙述性段落除外）
5. 本计划「结果与复盘」段写完，列出实际触动文件数、commit 列表、未解决项

## 可重复性与恢复

- 每批 1 个 commit，回滚 = `git revert <commit>`
- 批 D2 与批 H 强烈建议各自一个 PR（独立 commit），便于精确回滚
- T0 baseline 文件（`tmp/refactor-baseline-*.txt`）保留到全部完成；任何中间步骤 lint/test 异常时拉出对照
- 如果某批 lint/test 失败：
  - 不要在失败 commit 上叠改，先 `git restore --staged && git checkout -- .`（在分支上 reset 到上一 commit）
  - 重新看 grep 反查，找漏掉的引用（典型场景：`tools/`、`Data/`、`tmp/` 里有 lua 脚本也持有 require 字符串）
  - 修补后重新 commit

## 产物与备注

实施时记录每批的关键证据片段（lint 输出最后几行、busted summary、git grep 反查的 0 命中），以缩进方式保留在「意外与发现」段。

示例产物片段格式：

    [批 A] git grep -F "src.rules.market.paid_purchase_port"
    （0 行）
    
    [批 A] busted --run smoke
    Success: 412 / Failures: 0 / Errors: 0 / Pending: 0

## 接口与依赖

无库或外部服务依赖。仅依赖：

- `git`（mv + grep + revert）
- `perl`（in-place sed 替代，跨平台一致）
- `lua` + `tools/quality/lint.lua`
- `busted`（项目测试运行器，配置见 `.busted`）
- 可选 `tools/quality/arch/run.sh`（arch_view 静态扫描）

需要保持稳定的命名/路径（每批结束时这些必须存在且可 require）：

**批 A 结束后**：

- `require("src.rules.ports.paid_purchase")` 解析到 `src/rules/ports/paid_purchase.lua`

**批 B 结束后**：

- `require("src.player.actions.state_ops.balance")` 等 5 个新名字解析正确

**批 C 结束后**：

- `require("src.ui.render.widgets.cash_delta")` / `player_slots` / `presenter` 解析正确

**批 D1/D2 结束后**：

- `require("src.ui.state.modal")`
- `require("src.state.runtime")`

**批 E 结束后**：

- `require("src.turn.waits.await.action_anim")` / `choice` / `move_anim` / `seconds` / `simple` 解析正确

**批 F 结束后**：

- `require("src.rules.items.config")`
- `require("src.rules.land.board_utils")`
- `require("src.rules.land.landing_rules")`
- `require("src.rules.choice.handler_factory")`

**批 G 结束后**：

- `require("src.ui.render.tile")` / `assets` / `render_pipeline` 解析正确

**批 H 结束后**：

- `require("src.computer.agent")` 返回 `agent` 模块（原 core_agent 的 API）
- `require("src.ui.render.anim")` 返回 action_anim runtime 入口
- 子模块 `src.computer.agent.action` / `.decision` / `.path` 仍可 require
- 子模块 `src.ui.render.anim.handlers` / `.dice` / `.compute` 等仍可 require

**批 I 结束后**：

- `require("src.ui.render.board.scene")` 解析正确

---

**文档变更日志**（修改本计划时追加）：

- 2026-05-04 / 重构发起人：初版落盘。范围 9 批（A–I），决策保留 4 类不动项（state 四地标、foundation 子目录、ui_coord ui_ 前缀、ui_render runtime_ui）。
