# 用自定义事件替换 IntentDispatcher 监听器


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


把 Library/Monopoly/IntentDispatcher.lua 里的自建监听器改成使用 Globals/__init.lua 暴露的 RegisterCustomEvent / TriggerCustomEvent 等 API。用户视角的行为不变：触发 need_choice 仍会弹出选择框、写入 game.store；push_popup 仍会显示弹窗。完成后可以通过实际运行触发一次 need_choice 来观察选择框是否照常出现，或通过日志/断点确认 TriggerCustomEvent 被调用。


## 进度


- [x] (2025-09-25 16:10Z) 新建可执行计划并确定目标与范围
- [x] (2026-01-31 15:13Z) 读取相关文件并明确事件命名与数据结构（确认 RegisterCustomEvent 回调 data 形状）
- [x] (2026-01-31 15:13Z) 修改 IntentDispatcher.lua 以使用自定义事件 API，并新增 intent 事件名
- [x] (2026-01-31 15:13Z) 调整 Runtime 或其他监听处以接收自定义事件数据（由 IntentDispatcher.on 统一归一化，无需额外改动）
- [x] (2026-01-31 15:14Z) 验证行为不变并记录证据


## 意外与发现


- 观察：RegisterCustomEvent 回调的 data 可能是非 table 或被包装到 data["1"]。
  证据：Manager/System/EventHandlers.lua 的 normalize_payload 对 data["1"] 做兼容。
- 观察：事件命名集中在 Globals/MonopolyEvents.lua，采用 monopoly.<模块>.<动作> 的格式。
  证据：Globals/MonopolyEvents.lua 的 movement/land/market/chance 命名。


## 决策日志


- 决策：保留 IntentDispatcher 对外 API（on/dispatch），内部改为使用自定义事件 API。
  理由：调用点很多，保留接口可以最小化改动并降低回归风险。
  日期/作者：2025-09-25 Codex
- 决策：在 Globals/MonopolyEvents.lua 新增 intent 事件命名空间。
  理由：项目已有统一事件命名表，新增 intent 事件更清晰且便于复用。
  日期/作者：2025-09-25 Codex
- 决策：IntentDispatcher.on 回调内做 payload 归一化，沿用 EventHandlers 的 data["1"] 兼容逻辑。
  理由：避免自定义事件对 payload 做包装时丢失业务字段。
  日期/作者：2026-01-31 Codex
- 决策：push_popup 仍直接调用 ui_port，同时额外触发自定义事件。
  理由：保持现有 UI 行为不变，同时为事件监听提供入口。
  日期/作者：2026-01-31 Codex


## 结果与复盘


已完成 IntentDispatcher 事件替换与命名补充，need_choice/push_popup 仍保持原有 UI 行为，同时走自定义事件通道。回归脚本通过，未发现行为回退。若后续出现事件 payload 不一致的问题，优先在 IntentDispatcher 的归一化处处理。


## 背景与导读


Library/Monopoly/IntentDispatcher.lua 目前用本地 listeners 表实现事件订阅，dispatch 内部负责 need_choice 的 choice 生成和写入 game.store，并在 push_popup 时直接调用 game.ui_port。Globals/__init.lua 暴露了 RegisterCustomEvent、TriggerCustomEvent 等事件 API，项目中 MovementService、MarketService 等已有 TriggerCustomEvent 的用法。Manager/System/Runtime.lua 通过 IntentDispatcher.on 监听 need_choice 并打开选择框。Globals/MonopolyEvents.lua 是事件名称集中定义处。


## 里程碑


第一个里程碑是“事件命名与数据结构落地”。完成后，新增 intent 事件名，且可以从 IntentDispatcher 将 need_choice 通过 TriggerCustomEvent 发出，Runtime 能用 RegisterCustomEvent 接收并拿到原有 payload 结构。此里程碑验证方式是：触发一次 need_choice 后，能看到 choice_seq 递增且 UI 仍打开选择框。

第二个里程碑是“清理旧监听器实现并验证行为不变”。完成后，IntentDispatcher 不再维护 listeners 表，全部走自定义事件 API；push_popup 仍保持原有显示效果（可以保留直接调用 ui_port，同时允许事件派发）。验证方式是运行游戏流程中触发一次 push_popup，观察弹窗仍出现，并记录触发链路。


## 工作计划


先在 Globals/MonopolyEvents.lua 增加 intent 命名空间，定义 need_choice 与 push_popup 的事件名，采用与现有事件一致的前缀（如 monopoly.intent.need_choice）。然后修改 Library/Monopoly/IntentDispatcher.lua：移除 listeners 表与 emit 函数，新增事件名映射与 payload 归一化逻辑；IntentDispatcher.on 改为调用 RegisterCustomEvent，并在回调里把 data 还原成旧的 payload 结构再传给 fn；IntentDispatcher.dispatch 保持 choice 生成逻辑不变，生成 choice 后调用 TriggerCustomEvent 发送 intent 事件，同时保留 push_popup 直接调用 ui_port 以确保界面不变。最后调整 Manager/System/Runtime.lua（如果需要）以适配自定义事件的 payload 形状，并确认无需其他调用点改动。


## 具体步骤


在仓库根目录执行下列步骤，并在每步完成后更新进度和日志。

1) 确认 intent 事件名与使用位置。

   运行：
     rg -n "IntentDispatcher" Library Manager Globals

   预期：能看到 Runtime.lua 的监听点以及多个 dispatch 调用点。

2) 修改 Globals/MonopolyEvents.lua，新增 intent 事件名。

   预期：新增类似 intent.need_choice / intent.push_popup 的字符串常量。

3) 修改 Library/Monopoly/IntentDispatcher.lua。

   预期：listeners/emit 被移除，on/dispatch 使用 RegisterCustomEvent/TriggerCustomEvent；need_choice 仍写入 game.store，并在触发事件前组装 choice；push_popup 仍能触发 UI。

4) 如有必要，调整 Manager/System/Runtime.lua 的监听逻辑，使其从自定义事件回调中获得原有 payload。

   预期：Runtime 打开选择框的逻辑不变。


## 验证与验收


本仓库没有公开的自动化测试脚本。验证方式：

- 启动游戏流程（按项目常规启动方式），触发一次需要选择的场景（例如需要购买/使用道具时）。预期：choice_seq 递增，选择框正常显示。
- 触发一次 push_popup 场景。预期：弹窗仍出现，且无报错。
- 如无法运行游戏环境，至少通过日志或断点验证：TriggerCustomEvent 在 need_choice 时被调用，且 Runtime 的监听回调收到包含 choice 的 payload。


## 可重复性与恢复


本修改仅涉及 Lua 文件的编辑，可重复执行。若需要回退，使用版本管理工具恢复相关文件到修改前状态即可（例如 git restore 指定文件）。


## 产物与备注


预期的最小代码片段变化示例：

  MONOPOLY_EVENT.intent = {
    need_choice = "monopoly.intent.need_choice",
    push_popup = "monopoly.intent.push_popup",
  }

  RegisterCustomEvent(MONOPOLY_EVENT.intent.need_choice, function(_, _, data)
    local payload = normalize_payload(data)
    fn(payload)
  end)

  TriggerCustomEvent(MONOPOLY_EVENT.intent.need_choice, { game = game, choice = entry, choice_spec = spec })

  lua tests/regression.lua
  ..............................
  All regression checks passed (30)


## 接口与依赖


依赖 Globals/__init.lua 中已暴露的 API：RegisterCustomEvent、TriggerCustomEvent。IntentDispatcher.on 仍保持签名 on(kind, fn)，IntentDispatcher.dispatch 仍保持签名 dispatch(game, payload)，其中 payload 的 intent 结构与 choice_spec 结构保持不变。新增事件名来自 Globals/MonopolyEvents.lua 的 intent 命名空间，事件名格式为 monopoly.intent.<kind>。


更新记录：记录验证已完成与回归脚本输出，并补充结果复盘，便于后续复查与追踪。
