# Eggy 编辑器 UI 全屏测试执行记录（2026-02-20）

## 执行范围

- 计划名称：Eggy 编辑器 UI 全屏功能测试计划（双端 + 全量门禁）
- 目标屏幕：加载屏、基础屏、玩家选择屏、位置选择屏、遥控骰子屏、建筑升级屏、骰子屏、黑市屏、卡牌展示屏、破产展示屏、调试屏

## 环境

- 仓库：`/Users/billyq/Dev/Github/Lua/monopoly`
- 部署目标：`/Users/billyq/Documents/eggy/LuaSource_monopoly`
- 日期：2026-02-20

## 自动化门禁结果

### 1) 全量回归（前）

命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua /Users/billyq/Dev/Github/Lua/monopoly/.github/tests/regression.lua

结果：

    All regression checks passed (138)
    dep_rules ok
    tick ok

### 2) UI 专项回归（前）

命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua -e 'package.path=package.path..";./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua"; local h=require("TestHarness"); h.run_all({require("presentation_ui_timing_anim"),require("presentation_ui_model_dispatch"),require("presentation_ui_interaction"),require("presentation_ui_popup_market"),require("presentation_ui_action_status"),require("presentation_ui_action_anim")})'

结果：

    All regression checks passed (62)

### 3) UI 专项回归（后）

命令同上。

结果：

    All regression checks passed (62)

### 4) 全量回归（后）

命令同“全量回归（前）”。

结果：

    All regression checks passed (138)
    dep_rules ok
    tick ok

## 部署结果

命令：

    pwsh /Users/billyq/Dev/Github/Lua/monopoly/.github/scripts/deploy.ps1 -TargetPath "/Users/billyq/Documents/eggy/LuaSource_monopoly"

结果：脚本输出“部署完成！”，`Config/`、`src/`、`vendor/`、`main.lua`、`Data/UIManagerNodes.lua` 已复制到目标目录。

## 快速测试档位（2026-02-20 新增）

通过修改 `Config/GameplayRules.lua` 中的 `test_profile` 一行切换：

- `default`：默认地图与默认开局资源
- `ui_quick_all`：全屏综合快速触发（黑市/弹窗/建筑选择/基础交互）
- `ui_quick_choice`：Choice 专项快速触发（玩家选择/位置选择/遥控骰子）
- `ui_quick_bankruptcy`：破产展示专项快速触发

推荐手测顺序：

1. `ui_quick_all` 跑基础链路。
2. `ui_quick_choice` 跑三种选择屏。
3. `ui_quick_bankruptcy` 跑破产展示屏。

## 编辑器双端手测清单

说明：当前执行环境是终端，无法直接启动并操作 Eggy 双客户端 GUI。以下项需在编辑器中人工执行并回填结果。

| 屏幕 | 触发步骤 | 预期结果 | 本次状态 |
| --- | --- | --- | --- |
| 加载屏 | 进入对局初始化 | 出现后约 1 秒自动隐藏，切到基础屏 | 待人工执行 |
| 基础屏 | 加载屏关闭后 | 倒计时/行动按钮/托管按钮正常 | 待人工执行 |
| 调试屏 | 点击行动日志按钮或倒计时时钟 | 仅触发端切换，不串到另一端 | 待人工执行 |
| 骰子屏 | 当前玩家点击行动按钮 | 旋转 -> 结果 -> 自动收起 | 待人工执行 |
| 玩家选择屏 | 使用偷窃卡等玩家目标道具 | 目标可点，可提交/取消 | 待人工执行 |
| 位置选择屏 | 使用路障/导弹/怪兽等位置目标道具 | 前后/脚下按钮状态正确 | 待人工执行 |
| 遥控骰子屏 | 使用遥控骰子卡 | 1~6 可选，取消可用，确认生效 | 待人工执行 |
| 建筑升级屏 | 落地触发买地或升级选择 | 标题语义正确，确认/取消正确 | 待人工执行 |
| 黑市屏 | 到达黑市地块或黑市机会效果 | 选中后价格与图标联动，购买/关闭正常 | 待人工执行 |
| 卡牌展示屏 | 机会卡或道具卡弹窗 | 标题/图片/确认正常，超时可自动关闭 | 待人工执行 |
| 破产展示屏 | 玩家破产 | 双端都可见，文本和头像正确 | 待人工执行 |

## 代码层对照点（辅助人工定位）

- `src/app/bootstrap/UIBootstrap.lua`：加载屏显示/隐藏、基础屏切换
- `src/presentation/shared/UINodes.lua`：11 个屏幕节点命名
- `src/presentation/interaction/UIChoiceRoutePolicy.lua`：玩家/位置/遥控/建筑/黑市路由
- `src/presentation/render/ActionAnim.lua`：骰子屏时序
- `src/presentation/render/MarketView.lua`：黑市选中、价格、图标联动
- `src/presentation/ui/PopupRenderer.lua`：卡牌展示屏与破产展示屏
- `.github/tests/suites/presentation_ui.lua`：UI 交互主测试

## 当前结论

- 自动化门禁：通过
- 部署：通过
- 编辑器双端 11 屏手测：未在本终端环境执行，等待人工执行并回填
