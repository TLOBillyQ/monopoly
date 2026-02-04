# 清理事件与运行时常量模块

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角

把游戏事件与运行时常量整理为清晰的配置模块，并消除隐式全局依赖。完成后，事件常量统一从 `Config/MonopolyEvents.lua` 引用，运行时常量全部显式访问，功能行为不变但结构更可维护。验证方式是回归脚本通过且游戏启动与 UI 事件链路不报错。

## 进度

- [x] (2026-02-04 08:55Z) 迁移 `MonopolyEvents` 到 `Config/` 并统一 `resolve_intent` 入口
- [x] (2026-02-04 08:55Z) 更新所有事件引用路径与调用点
- [x] (2026-02-04 08:58Z) 将 `RuntimeConstants` 改为返回 table，并更新所有调用方
- [x] (2026-02-04 08:59Z) 整理 `GameplayRules` 与 `UIEvents` 可读性
- [x] (2026-02-04 09:00Z) 运行回归脚本并记录结果

## 意外与发现

- 观察：测试环境缺少 `math.Quaternion`，导致 `Config/RuntimeConstants.lua` 直接初始化时报错。
  证据：`RuntimeConstants.lua:1: attempt to call field 'Quaternion' (a nil value)`
  处理：增加 `_vec3` / `_quat` 兜底，在缺失时返回简单表结构，避免测试失败。

## 决策日志

- 决策：`MonopolyEvents` 迁到 `Config/MonopolyEvents.lua`，并新增 `resolve_intent(kind)`。
  理由：事件常量属于配置，统一入口能删除重复逻辑。
  日期/作者：2026-02-04 / Codex。

- 决策：`RuntimeConstants` 改为 table 返回，禁止全局常量读取。
  理由：显式依赖更安全可读，减少隐式耦合。
  日期/作者：2026-02-04 / Codex。

- 决策：未引用的运行时常量先保留并注释说明。
  理由：避免潜在外部依赖被破坏。
  日期/作者：2026-02-04 / Codex。

- 决策：`RuntimeConstants` 内增加 `_vec3` / `_quat` 兜底构造。
  理由：回归脚本环境缺少 `math.Quaternion`，需要避免初始化报错。
  日期/作者：2026-02-04 / Codex。

## 结果与复盘

已完成事件与运行时常量清理，回归脚本通过。运行时常量改为显式 table 访问，事件常量迁移到 `Config/` 并统一解析入口。未发现遗留事项。

## 背景与导读

事件常量目前位于 `src/game/MonopolyEvents.lua`，并被大量模块依赖；同时多个模块内包含重复的意图事件名解析函数。运行时常量位于 `Config/RuntimeConstants.lua`，以全局变量形式暴露，导致调用方隐式依赖。需要把事件常量迁入 `Config/` 并引入统一解析入口，同时把运行时常量改为 table 返回并显式引用。

相关文件与模块：

  - 事件常量：`src/game/MonopolyEvents.lua` -> 迁到 `Config/MonopolyEvents.lua`
  - 运行时常量：`Config/RuntimeConstants.lua`
  - 事件引用：`src/app/init.lua`、`src/ui/UIEventHandlers.lua`、`src/game/**` 多处
  - 运行时常量引用：`Config/RuntimeGlobals.lua`、`Config/RuntimeECA.lua`、`src/ui/ActionAnim.lua`、`src/ui/MoveAnim.lua`、`src/ui/BoardView.lua`、`src/game/turn/GameplayLoop.lua`

## 工作计划

先创建 `Config/MonopolyEvents.lua` 并加入 `resolve_intent`，随后删除旧文件并更新所有 `require` 与事件名解析逻辑。接着把 `RuntimeConstants` 改成 table 返回，逐一修正所有调用方对全局常量的引用。最后整理 `Config/GameplayRules.lua` 与 `Config/UIEvents.lua` 的可读性并补充必要断言。完成后运行回归脚本记录结果。

## 具体步骤

在仓库根目录按以下步骤实施：

1. 新建 `Config/MonopolyEvents.lua`，复制原事件表并添加 `resolve_intent(kind)`；删除 `src/game/MonopolyEvents.lua`。
2. 全量替换事件常量 `require` 路径到 `Config.MonopolyEvents`。
3. 删除各模块内的 `_resolve_event_name`，改为调用 `monopoly_events.resolve_intent("need_choice")` / `monopoly_events.resolve_intent("push_popup")`。
4. 重写 `Config/RuntimeConstants.lua` 为 table 返回，保留未引用字段并注释。
5. 更新运行时常量调用方为 `runtime_constants.xxx` 显式访问。
6. 调整 `Config/GameplayRules.lua` 字段顺序与局部变量命名，保持值不变。
7. 在 `Config/UIEvents.lua` 的 `send_to_all` 中加入对 `all_roles` 的断言提示。
8. 运行 `lua .agents/tests/regression.lua` 并记录结果。

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期输出包含：

  All regression checks passed (36)

启动游戏后确认：加载屏切换到基础屏，UI 事件触发无报错。

## 可重复性与恢复

所有步骤可重复执行。若需回退：

  - 还原 `src/game/MonopolyEvents.lua` 并恢复所有 `require` 路径与解析逻辑。
  - 将 `Config/RuntimeConstants.lua` 恢复为全局变量写法并还原引用。

## 产物与备注

  - 新增：`Config/MonopolyEvents.lua`
  - 删除：`src/game/MonopolyEvents.lua`
  - 更新：事件引用与解析、运行时常量引用、`Config/GameplayRules.lua`、`Config/UIEvents.lua`

## 接口与依赖

必须新增并使用的接口：

  - `Config/MonopolyEvents.resolve_intent(kind)`：返回 `intent[kind]` 的事件名字符串。

运行时常量以 `runtime_constants.xxx` 形式显式引用，不再读取全局。

计划变更说明：补充实际执行进度、测试结果与回归环境缺失 `math.Quaternion` 的处理记录，确保计划与实现一致。
