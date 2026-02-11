# 接入破产展示屏


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agents/PLANS.md`，实施过程中需要保持本文件自洽且完整。


## 目的 / 全局视角


当任意玩家破产出局时，弹出“破产展示屏”，展示破产原因与玩家头像，并按现有弹窗超时逻辑自动关闭。完成后应能通过触发破产路径看到该屏幕出现并自动关闭。


## 进度


- [x] (2026-02-11 00:00Z) 清空并重写 `.agents/PLAN_CURRENT.md`
- [x] (2026-02-11 00:30Z) 接入破产展示屏 UI 与弹窗流程
- [x] (2026-02-11 00:30Z) 破产逻辑发出展示请求并补充原因文本
- [x] (2026-02-11 00:30Z) 验证与记录结果


## 意外与发现


- 观察：暂无
  证据：暂无


## 决策日志


- 决策：破产展示屏在任意出局时弹出，文案由调用方提供，自动超时关闭
  理由：符合用户选择且复用现有弹窗超时机制
  日期/作者：2026-02-11 / Codex


## 结果与复盘


已完成破产展示屏接入与破产原因传递。回归脚本通过，等待手动触发破产路径确认表现。

验证结果：`lua .agents/tests/regression.lua` 通过（100/100）。


## 背景与导读


当前弹窗仅接入“卡牌展示屏”，入口在 `src/ui/UIView.lua` 与 `src/ui/UIModalPresenter.lua`，通过 `push_popup` 展示。UI 资源里已经存在“破产展示屏”与相关节点，但未接入。破产逻辑集中在 `src/game/game/Bankruptcy.lua`，被租金、税务、道具、医院、机会卡等路径调用。


## 工作计划


先在 UI 层新增“破产展示屏”的节点映射与画布常量，并在弹窗展示逻辑中根据 `payload.kind` 选择卡牌或破产屏。破产屏展示文字与头像，不启用确认按钮。随后在破产逻辑处统一发送 `push_popup`，并在各破产触发点传入原因文本。最后运行回归脚本并手动触发破产验证。


## 具体步骤


1. 修改 `src/ui/UIView.lua`，新增 `bankruptcy_screen`（root、text、avatar）并增加 `popup_kind` 字段。
2. 修改 `src/ui/UICanvasCoordinator.lua`，新增 `CANVAS_BANKRUPTCY = "破产展示屏"`。
3. 修改 `src/ui/UIModalPresenter.lua`，根据 `payload.kind` 切换画布并设置文案与头像，关闭时隐藏对应屏幕并清理状态。
4. 修改 `src/ui/UIInputLockPolicy.lua`，仅在卡牌弹窗时启用确认按钮。
5. 修改 `src/game/game/Bankruptcy.lua`，增加 `opts` 参数并发出破产弹窗 payload。
6. 修改 `src/game/land/LandActions.lua`、`src/game/game/GameState.lua`、`src/game/chance/ChanceRegistry.lua`、`src/game/item/ItemPostEffects.lua`，在破产触发时传入原因文本。


## 验证与验收


- 运行回归脚本：
  在 `c:\Users\Lzx_8\Desktop\dev\monopoly` 执行：
    lua .agents/tests/regression.lua
  预期：脚本通过且无报错。

- 手动验证：触发任意破产路径，观察“破产展示屏”出现、文字正确、头像显示，并在超时后自动关闭。


## 可重复性与恢复


改动为可逆代码修改，无数据迁移。若出现问题，可回退新增的破产弹窗分支与原因传递逻辑。


## 产物与备注


破产弹窗 payload 示例：
  { kind = "bankruptcy", player_id = 2, text = "玩家2 资金不足，支付租金后破产" }


## 接口与依赖


- `bankruptcy.eliminate(game, player, opts)` 新增 `opts.reason` 可选字段。
- `push_popup` 新增 `payload.kind = "bankruptcy"`，使用 `payload.text` 与 `payload.player_id`。


(2026-02-11) 本计划由 Codex 创建，原因：实现“破产展示屏”接入与触发逻辑。
(2026-02-11) 更新进度与结果，原因：已完成实现并记录回归测试结果。
