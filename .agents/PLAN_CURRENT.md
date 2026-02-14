# 执行计划：黑市卡牌显示补全与不可购买态

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

黑市界面最多展示 10 张卡牌，即使只有 6 张可购买，也要把剩余槽位用不可购买项补齐并禁用点击。完成后，进入黑市能看到 10 个槽位，且默认选中第一张可购买卡牌。验证方式是进入黑市观察显示数量与点击行为。

## 进度

- [x] (2026-02-14 03:12Z) 读取现状与确认约束，定位列表来源与渲染链路。
- [x] (2026-02-14 03:14Z) 实现可见列表排序与可购买标记，补齐到 10 项。
- [x] (2026-02-14 03:18Z) 更新黑市 UI 渲染与默认选中逻辑，禁用不可购买项。
- [x] (2026-02-14 03:20Z) 运行最小验证并记录验收结果。

## 意外与发现

本次未发现新的意外行为或性能权衡。

## 决策日志

决策：黑市最多展示 10 张，不可购买项显示但不可点，默认选中第一张可购买。  
理由：匹配现有 10 槽位设计并避免默认选中不可购买。  
日期/作者：2026-02-14 / Codex

## 结果与复盘

已完成黑市可见列表与 UI 渲染调整，界面始终补齐到 10 张且不可购买项禁用。默认选中第一张可购买项，若无可购买则不进入黑市并弹提示。验证通过后本轮任务闭环。

## 背景与导读

黑市槽位定义在 `src/presentation/shared/MarketLayout.lua`，已有 10 个按钮、标签与底框。黑市商品列表由 `src/game/systems/market/Market.lua` 生成，原逻辑只输出可购买项导致 UI 仅填充 6 张。UI 渲染与默认选中逻辑在 `src/presentation/render/MarketView.lua`，选择数据通过 `src/presentation/ui/UIChoice.lua` 与 `src/presentation/state/UIModelProjection.lua` 进入 UI 模型。

## 工作计划

先在 `src/game/systems/market/Market.lua` 生成可见列表，将可购买项按 order 排序后放前面，再用不可购买项补齐到 10 个，并在 options 中写入 `can_buy`。若无可购买项，保持弹窗提示不进入黑市。随后在 `src/presentation/ui/UIChoice.lua` 透传 `can_buy` 到 UI 选项对象。最后在 `src/presentation/render/MarketView.lua` 禁用不可购买按钮，并将默认选中修正为第一张可购买项。

## 具体步骤

在仓库根目录编辑 `src/game/systems/market/Market.lua`、`src/presentation/ui/UIChoice.lua`、`src/presentation/render/MarketView.lua` 完成逻辑改动。完成后在仓库根目录执行以下命令进行最小验证，并观察是否无新增失败输出。

    lua .agents/tests/gameplay_loop_no_ui.lua

## 验证与验收

进入黑市时可见 10 张卡牌；不可购买项按钮不可点击；默认选中第一张可购买项；若无可购买项则弹出“暂无可购买商品”且不进入黑市。最小测试脚本运行无新增失败。

## 可重复性与恢复

本次修改仅涉及 Lua 逻辑，可重复执行。若出现异常，回退上述三处文件改动即可恢复原行为。

## 产物与备注

本次修改涉及 `src/game/systems/market/Market.lua`、`src/presentation/ui/UIChoice.lua`、`src/presentation/render/MarketView.lua` 与 `.agents/PLAN_CURRENT.md`。

## 接口与依赖

`choice.options[]` 新增字段 `can_buy`，用于 UI 渲染禁用与默认选中判断，不引入新依赖，复用现有 `_can_buy_entry` 与 UI 渲染接口。

变更说明（2026-02-14 / Codex）：清空并重写计划为“黑市卡牌显示补全与不可购买态”，补齐进度、决策、验收与产物信息。
