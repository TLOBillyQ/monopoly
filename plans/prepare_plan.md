## 需求基线

本项目需求以 `design/` 为唯一来源：`design/蛋仔策划案--大富翁.docx`（已清洗为 `design/蛋仔策划案--大富翁.cleaned.txt`）与 `design/*.xlsx`。`src/config/*.lua` 为设计表生成产物，需求变更应先改设计表再导出。

## 设计要点清单

1) 基本规则：2~4人；单人自动补足 AI；回合制；胜利=仅剩一人或时间结束资产最高（并列胜）。  
2) 初始：起点出生；初始金币100K；道具槽5；行动超时10秒默认确认。  
3) 回合结构：行动前/行动中/行动后；前后可用道具；行动中投骰自动移动并触发事件。  
4) 事件：空地购买/自有加盖/他人租金；机会卡/道具卡；起点奖励；黑市购买；医院/深山停留；税务局缴税；破产清退。  
5) 道具：19种；按时机分类；满槽失败；可丢弃。  
6) 机会卡：34张；权重抽；含金钱、移动、拆建、重置、送医院/税务/黑市、道具、丢地块等。  
7) 地块：道路/建筑双坐标；加盖3次；租金/总价值规则；连片同主租金累计。  
8) 座驾：影响骰子数量；部分不可摧毁；黑市可购买并替换。  
9) AI：自动确认、尽量使用道具，并有明确优先级。  
10) 表现：行动中视角跟随、弹窗、停留提示、动画等。  

## 需求到 src 的对照（现状）

### 回合与胜负
- 设计：回合制、胜利条件、回合三阶段。  
- src 现状：  
  - `src/game.lua`：胜负判定（淘汰或回合上限资产最高）。  
  - `src/gameplay/turn_start.lua` / `turn_roll.lua` / `turn_move.lua` / `turn_land.lua` / `turn_post.lua` / `turn_end.lua`：回合流程。  
  - `src/config/constants.lua`：回合上限、超时秒数等。  

### 初始与玩家状态
- 设计：起点出生、初始金币100K、道具槽5。  
- src 现状：  
  - `src/core/player.lua`：初始金币与余额。  
  - `src/config/constants.lua`：`starting_cash=100000`、`inventory_slots=5`。  
  - `src/core/inventory.lua`：背包容量逻辑。  

### 移动与路线
- 设计：投骰移动、岔路按奇偶走向、经过起点奖励。  
- src 现状：  
  - `src/core/board.lua`：`step_forward_by_facing` 支持奇偶分支。  
  - `src/gameplay/movement_service.lua`：移动、经过起点奖励、路障/黑市/偷窃中断。  

### 地块与租金
- 设计：空地购买、加盖最多3次、租金与总价值规则、连片租金累计。  
- src 现状：  
  - `src/gameplay/land.lua`：购买/加盖/租金与强征卡流程。  
  - `src/gameplay/land_pricing.lua`：升级费用与租金。  
  - `src/gameplay/land_actions.lua`：连片租金计算、强征/免租/破产处理。  

### 事件地块
- 设计：起点/黑市/医院/深山/税务局/道具卡/机会卡。  
- src 现状：  
  - `src/gameplay/landing.lua`：落地事件分发。  
  - `src/gameplay/player_effects.lua`：医院/深山停留。  
  - `src/gameplay/market_service.lua`：黑市购买逻辑。  

### 道具系统（19种）
- 设计：时机分类、满槽失败、可丢弃、AI 可用。  
- src 现状：  
  - `src/config/items.lua`：19道具配置与时机。  
  - `src/gameplay/item_*`：使用、目标选择、效果、丢弃。  
  - `src/gameplay/item_phase.lua`：行动前/投骰后/行动后使用窗口。  
  - `src/gameplay/agent.lua` / `src/gameplay/item_strategy.lua`：AI 使用规则。  

### 机会卡
- 设计：34张，权重抽，负面受天使影响。  
- src 现状：  
  - `src/config/chance_cards.lua`：机会卡配置。  
  - `src/gameplay/chance.lua`：效果执行（含天使免负面）。  

### 座驾
- 设计：骰子数量变化、部分不可摧毁、黑市替换。  
- src 现状：  
  - `src/config/vehicles.lua`：座驾参数与不可摧毁。  
  - `src/gameplay/player_vehicle.lua`：骰子数量与免毁判定。  
  - `src/gameplay/market_service.lua`：购买替换流程。  

### 破产
- 设计：资金归零出局、地块清空、观战。  
- src 现状：  
  - `src/gameplay/bankruptcy_service.lua`：清空地块、清空道具、淘汰。  

### UI/表现
- 设计：视角跟随、弹窗、动画。  
- src 现状：  
  - 逻辑侧只派发 intent（`src/util/intent_dispatcher.lua`），表现层在适配层/UI 端完成。  

## 关键差异与待确认（Update: 已确认）

1) 机会卡数量：设计写 34 张，`src/config/chance_cards.lua` 统计为 37 条。以37条为准，对齐design/机会表。
2) “每格道路最多摆 4 角色”在 `src/` 未见限制逻辑。  此设计冗余，游戏玩家数量不会超过4.
3) “行动中视角跟随/停留表现/弹窗动画”属于 UI 实现，目前在 `src/` 仅有意图派发。 弹窗动画需要实现，视角跟随与停留表现在架构思考时提供占位，留待后续版本实现。
4) “超时10秒默认确认”仅覆盖选择型流程（`AdapterLayer.step_choice_timeout`），未覆盖所有 UI 交互场景。 重要！需要覆盖所有UI交互场景，尤其是会卡死流程的地方。

## 可参考的 deepfuture 架构要点（来自 docs/architecture）

- 入口与帧循环（`docs/architecture/01-entry-and-loop.zh-CN.md`）：入口只做 wiring，不写规则。此版本 `main.lua`/适配层应只负责：初始化资源、UI 管理器、状态机/回合管理器、输入回调；具体规则仍落在 `gameplay`。
- 状态机与协程调度（`docs/architecture/02-flow-state-machine.zh-CN.md`）：长流程写成“顺序逻辑 + 等待点”。本项目可在 `turn_manager` 或适配层引入明确的等待状态（如动画完成、弹窗确认），避免用层层回调拆流程。
- 数据驱动资产（`docs/architecture/03-data-driven-assets.zh-CN.md`）：可调参数与资源表从数据中读取。对应本项目：`design/*.xlsx` 与 `ui_data.lua`/`refs.lua` 做唯一配置源，UI 名称与资源映射不写死在代码里。
- UI 组织与渲染（`docs/architecture/04-ui-rendering.zh-CN.md`）：视觉层统一入口，逻辑只发意图。对应本项目：保留 UI 管理器作为单点装配，`gameplay` 仅派发 intent/choice，不直接操作 UI 组件。
- 输入系统（`docs/architecture/05-input.zh-CN.md`）：focus/命中作为统一输入入口。对应本项目：把“choice/弹窗/按钮”视为统一的 focus 对象，适配层集中处理点击/超时/自动确认，不在逻辑层写 UI 细节。
- 存档与后台服务（`docs/architecture/06-persistence-services.zh-CN.md`）：I/O 下沉服务、主线程只管内存态。若此版本要做存档，应将读写放在适配层/服务层，`gameplay` 仅提供可序列化状态。
- 本地化与字体（`docs/architecture/07-localization-fonts.zh-CN.md`）：文本模板与语言切换分层。若 UI 文案需多语言，可把提示文案集中到表/配置，避免散落在逻辑里。
- 构建与发布（`docs/architecture/08-build-and-deploy.zh-CN.md`）：运行时与内容分离。对应 Eggy 适配可保持“逻辑/资源分包”，便于后续迭代与热更新。

## 结论

后续所有版本（原版/重构版）都必须以 `design/` 的需求为唯一依据。重构计划需要优先补齐差异项，并在 UI/适配层明确表现责任归属。
