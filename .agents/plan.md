# R18 运行时沙盒限制疑点收敛执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护，实施者在修改代码前后都必须先回填本文件，再继续推进。

## 目的 / 全局视角


本轮目标是把已确认的运行时沙盒疑点收敛到“可发布、可验证、可回归”的状态。用户可见收益是两点：第一，发布环境不再因为被裁剪 API（`os/debug/rawget/type=="number"` 相关）触发潜在崩溃或行为分叉；第二，核心回合与提示文本在 Eggy 沙盒的数值语义下保持稳定，不再依赖“字符串与数字隐式拼接”。

改动完成后，验证者应能直接观察到：`src/` 扫描不再命中本计划定义的禁用模式；定向回归与全量回归通过；`Await.seconds` 在 `os=nil` 条件下不报错；镜头跟随在“当前玩家无效时寻找下一位玩家”的分支上不再依赖 `type(...) == "number"`。

## 进度


- [x] (2026-03-03 20:41 +08:00) 重读 `.agents/harness/PLANS.md` 与现有 `.agents/plan.md`，确认格式与活文档要求。
- [x] (2026-03-03 20:42 +08:00) 基于最新工作树重扫疑点并固化证据：`os.clock`、`type~=number`、`rawget`、`coroutine`、高置信隐式拼接。
- [x] (2026-03-03 20:43 +08:00) 生成并写入 R18 可执行计划骨架，明确里程碑、边界、验收与恢复策略。
- [x] (2026-03-03 20:46 +08:00) 完成里程碑 1：修复 `Await.seconds`、`TurnCameraPolicy`、`init.lua`、`CompositionRoot.lua` 的沙盒兼容问题。
- [x] (2026-03-03 20:49 +08:00) 完成里程碑 2：落地高优先级数值拼接显式转换，主链路目标文件全部改完。
- [x] (2026-03-03 20:50 +08:00) 完成里程碑 3：扩展 `forbidden_globals` 规则并通过静态门禁。
- [x] (2026-03-03 20:52 +08:00) 完成里程碑 4：通过定向验证与 `tests/regression.lua` 全量回归（231 checks）。

## 意外与发现


- 观察：`src/game/runtime_coroutine/Await.lua` 的 `await.seconds` 仍使用 `opts.now_fn or os.clock`，在沙盒 `os=nil` 时会直接抛错。
  证据：本地执行 `lua -e "local old_os=os; os=nil; local await=require('src.game.runtime_coroutine.Await'); local s={_seconds_wait={}}; local ok,err=pcall(function() await.seconds(s,1,{}) end); print(ok,err); os=old_os"`，返回 `false` 与 `attempt to index global 'os' (a nil value)`。

- 观察：`src/game/flow/turn/TurnCameraPolicy.lua` 仍使用 `type(current_index) ~= "number"`，与项目“数值统一走 NumberUtils”约束冲突，也会影响 Eggy `integer/fixed` 语义下的兼容。
  证据：命中行 `TurnCameraPolicy.lua:18`。

- 观察：高置信“可能触发隐式数值拼接”的命中共 42 行，分布于 21 文件，但其中有一部分是已 `tostring` 的安全构造或字符串变量拼接，需要分层清洗。
  证据：扫描统计 `high_confidence_numeric_concat_lines=42`，主要集中在 `land/items/movement/market` 与 `Config/Maps/DefaultMap.lua`。

- 观察：`lua_env.md` 与现状存在文档/实现差异，`src/` 里仍可见 `rawget` 与 `os.clock` 依赖点，且回合引擎依赖 `coroutine.*`。
  证据：`init.lua:14`、`CompositionRoot.lua:92`、`Await.lua:170`、`Scheduler.lua/TurnScript.lua`。

- 观察：`CompositionRoot` 去掉 `rawget` 后，直接用字段访问会把“实例”误判为“类”，导致回归大面积失败。
  证据：首次回归出现 `attempt to index field 'turn' (a nil value)` 等 111 个失败；修复类/实例判定后恢复通过。

- 观察：`RuntimeEventBridge` 的 `debug.getupvalue` 预检查在现有测试契约中仍有价值，不能机械移除。
  证据：`presentation_ui` 用例要求“wrapped TriggerCustomEvent”不应被调用；恢复 guarded 预检查后该断言恢复通过。

## 决策日志


- 决策：R18 采用“先消除硬失败，再消除语义风险，最后补静态守卫”的顺序，不一次性全仓替换。
  理由：`Await.seconds` 与 `type~=number` 属于发布环境风险最高路径，先收敛可立即降低线上不确定性。
  日期/作者：2026-03-03 / Codex

- 决策：对数值文本输出采用“金额/步数/回合等业务数值优先 `NumberUtils.format_integer_part`，标识类值（id/index）用 `tostring`”的双轨策略。
  理由：满足 `lua_env` 无隐式转换约束，同时避免把标识符误格式化为金额语义。
  日期/作者：2026-03-03 / Codex

- 决策：`coroutine` 相关暂不迁移，纳入“文档对齐 + 启动前置检查”而非架构替换。
  理由：当前回合引擎核心即协程模型，迁移成本高且超出本轮“沙盒疑点收敛”范围。
  日期/作者：2026-03-03 / Codex

- 决策：在 `tests/internal/forbidden_globals.lua` 扩展规则，守卫 `rawget`、`type==/~=number`、`os.clock`、`debug.traceback` 在 `src/` 的出现。
  理由：把本轮问题固化为可执行门禁，避免回归。
  日期/作者：2026-03-03 / Codex

- 决策：保留 `RuntimeEventBridge` 中“带 guard 的 `debug.getupvalue` 预检查”，不纳入本轮禁用项。
  理由：该检查承担“wrapped TriggerCustomEvent 降级避让”契约，且已对 `debug` 缺失做守卫，不会在沙盒中硬失败。
  日期/作者：2026-03-03 / Codex

## 结果与复盘


R18 已完成。A 类与 B 类目标全部落地，C 类（`coroutine` 文档对齐）保持追踪但不在本轮改动范围。

完成结果如下：`Await.seconds` 不再依赖 `os.clock`；`TurnCameraPolicy` 改为 `NumberUtils.to_integer`；`rawget` 在 `src/` 清零；高优先级数值拼接点已在主链路完成显式转换；`forbidden_globals` 新规则生效并通过。定向命令与全量回归均已通过，回归输出为 `All regression checks passed (231)`。

本轮经验教训是：替换 `rawget` 时必须保留“类/实例判定”的原始语义，否则会触发隐蔽的大面积行为回退；此外，`debug` 相关逻辑应区分“硬依赖”与“有守卫的降级检查”。

## 背景与导读


本任务只处理运行时相关的 `src/` 与 `Config/`，目标不是重构玩法，而是让代码在 Eggy 沙盒限制下行为可预期。这里的“沙盒限制”指 `docs/eggy/lua_env.md` 里声明的环境约束，核心包括库裁剪、数值语义差异、以及字符串与数字不能隐式拼接。

关键入口分三组。第一组是回合协程与等待逻辑：`src/game/runtime_coroutine/Await.lua`、`Scheduler.lua`、`TurnScript.lua`。第二组是回合到表现层的关键路径：`src/game/flow/turn/TurnCameraPolicy.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/systems/movement/Movement.lua`。第三组是文本构造密集区：`src/game/systems/land/*`、`src/game/systems/items/*`、`src/game/systems/market/*` 与 `Config/Maps/DefaultMap.lua`。

本计划把疑点分为三类。A 类是可直接导致发布环境错误的硬依赖（例如 `os.clock` 未守卫、`rawget`）；B 类是数值语义风险（`type~=number`、隐式拼接）；C 类是文档与实现不一致（`coroutine` 依赖与 `lua_env` 描述差异）。R18 只承诺完成 A+B，并把 C 变成可追踪动作。

## 里程碑


里程碑 1 只处理“硬失败点”。范围是 `Await.seconds`、`TurnCameraPolicy`、`init.lua`、`CompositionRoot.lua`。完成标准是：`src/` 不再出现 `rawget(`；`TurnCameraPolicy` 不再使用 `type(... ) ~= "number"`；`Await.seconds` 在 `os=nil` 下可安全返回，不抛异常。

里程碑 2 处理“高优先级隐式数值拼接”。范围锁定 gameplay 主链路与默认地图构造，不做全仓“机械替换”。完成标准是：本计划列出的目标文件完成显式转换；关键路径回归通过；不引入新的 `tonumber` 或 `type==number`。

里程碑 3 处理“守卫与证据”。范围是 `tests/internal/forbidden_globals.lua` 与相关回归入口。完成标准是：新增规则生效，触发时能给出明确替代建议；常规回归全绿。

里程碑 4 进行“闭环验收与文档回填”。范围是测试执行、证据摘录、计划更新。完成标准是：`进度/决策/结果` 完整同步，计划可被新人单独执行。

## 工作计划


第一步会在 `src/game/runtime_coroutine/Await.lua` 去掉对 `os.clock` 的直接依赖。实现方式是把 `await.seconds` 改为“优先使用 `opts.now_fn`；不存在则使用安全降级路径并立即完成等待”。这样可以在沙盒不提供 `os` 时保持可运行，并避免死等。

第二步会在 `src/game/flow/turn/TurnCameraPolicy.lua` 引入 `NumberUtils`，把 `type(current_index) ~= "number"` 改为 `NumberUtils.to_integer(current_index)` 判定，确保 `integer/fixed/number` 都可进入同一逻辑分支。该变更直接影响“当前玩家无效时寻找下一位玩家”的兜底路径。

第三步会移除 `rawget` 依赖。`src/app/init.lua` 用 `(_G and _G.STARTUP_TEST_PROFILE)` 读取启动 profile，并保留默认值兜底。`src/game/core/runtime/CompositionRoot.lua` 用显式字段与函数类型判断替代 `rawget(game_or_class, ...)`。

第四步会修复里程碑 2 的隐式拼接目标文件。预期修改文件包括 `Config/Maps/DefaultMap.lua`、`TurnRoll.lua`、`LocationOps.lua`、`ItemHandlers.lua`、`ItemPostEffects.lua`、`ItemRoadblock.lua`、`LandRules.lua`、`BaseLandEffects.lua`、`Choice.lua`、`Purchase.lua`、`Movement.lua`、`ItemDemolish.lua`、`ActionAnimTipText.lua`。所有业务数值文本改为 `NumberUtils.format_integer_part(...)` 或 `tostring(...)` 的显式转换。

第五步会把规则固化到 `tests/internal/forbidden_globals.lua`，新增对 `rawget`、`type==/~=number`、`os.clock`、`debug.traceback` 的检测，并在 `replacement` 字段给出统一替代方向（`NumberUtils`、运行时端口、`traceback` 等）。

## 具体步骤


所有命令在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先记录实施前快照，确保后续可对比。

    git status --short
    lua -e "local old_os=os; os=nil; local await=require('src.game.runtime_coroutine.Await'); local s={_seconds_wait={}}; local ok,err=pcall(function() await.seconds(s,1,{}) end); print('await.seconds pre=',ok,err); os=old_os"

按里程碑 1 修改并做定向检查。

    lua tests/internal/forbidden_globals.lua
    lua -e "local old_os=os; os=nil; local await=require('src.game.runtime_coroutine.Await'); local s={_seconds_wait={}}; local ok,err=pcall(function() await.seconds(s,1,{}) end); print('await.seconds post=',ok,err); os=old_os"

按里程碑 2 修改后跑主链路回归。

    lua -e "package.path='?.lua;'..package.path; local _=require('tests.suites.test_profiles'); print('test_profiles load ok')"
    lua tests/regression.lua

完成里程碑 3 后再次执行静态门禁，确认新规则不过度误伤。

    lua tests/internal/forbidden_globals.lua

最后整理变更并回填计划文档。

    git diff -- .agents/plan.md src tests docs
    git status --short

## 验证与验收


验收分为“行为”和“约束”两条线。行为线要求回归通过，至少包含 `lua tests/regression.lua` 全量运行成功；约束线要求 `lua tests/internal/forbidden_globals.lua` 不再命中本轮新增禁用模式。

对 `Await.seconds` 的专项验收必须包含 `os=nil` 场景。变更前脚本输出应出现 `attempt to index global 'os'`；变更后脚本输出必须是 `ok=true` 或等价的非异常结果。

对镜头兜底逻辑的专项验收必须覆盖“当前位玩家无效，需寻找下一位可跟随玩家”的路径。最低标准是对应单测通过；如果已有可复现场景，再补一次默认部署实测，确认镜头仍跟随当前回合玩家。

## 可重复性与恢复


本计划按里程碑增量执行，每个里程碑都可以独立提交和回滚。若里程碑 2 出现回归，优先保留里程碑 1 与里程碑 3，临时回退仅数值拼接改动，再逐文件二分定位问题。禁止使用破坏性历史命令，恢复方式以普通反向提交为准。

若新增静态规则出现误报，先在计划的“决策日志”记录误报模式，再在规则里做白名单或更精确正则，避免直接删除守卫。

## 产物与备注


实施前扫描证据（2026-03-03）：

    os.clock 命中:
      src/app/bootstrap/runtime_install/RuntimePortDefaults.lua:45
      src/core/runtime_ports/DefaultPorts.lua:142
      src/game/runtime_coroutine/Await.lua:170

    type~=number 命中:
      src/game/flow/turn/TurnCameraPolicy.lua:18

    rawget 命中:
      src/app/init.lua:14
      src/game/core/runtime/CompositionRoot.lua:92

    高置信隐式拼接命中:
      high_confidence_numeric_concat_lines=42

`lua_env.md` 关键约束摘录（用于本计划对照）：移除 `io/os/package/debug`，不支持字符串与数字隐式转换。

实施后验收证据（2026-03-03）：

    lua tests/internal/forbidden_globals.lua
      forbidden_globals ok

    lua -e "... os=nil ... await.seconds ..."
      await.seconds os=nil ok= true type= table

    lua tests/regression.lua
      All regression checks passed (231)
      dep_rules ok
      tick ok
      forbidden_globals ok

## 接口与依赖


本轮不新增第三方依赖，只依赖现有 `NumberUtils`、回归测试框架和 Lua 运行环境。实施后应满足以下接口约束。

`src/game/runtime_coroutine/Await.lua` 中 `await.seconds(session, sec, opts)` 继续保持原函数签名，不引入调用方破坏性改动；仅调整内部默认计时来源和降级行为。

`src/game/flow/turn/TurnCameraPolicy.lua` 中 `sync_follow(game, state, ports, ui_refreshed)` 对外行为不变，仍由当前回合玩家驱动跟随；内部类型判定改用 `NumberUtils`。

`tests/internal/forbidden_globals.lua` 的输出格式保持兼容，新增规则也必须按 `forbidden_globals: path:line uses ...` 的可读形式报错，便于 CI 与本地定位。

## 文档更新记录


2026-03-03（R18 创建）：基于最新代码库重扫，确认本轮疑点仍存在（`os.clock`、`type~=number`、`rawget`、高置信隐式拼接 42 行），并将旧的“代码膨胀收敛”计划替换为“沙盒限制疑点收敛”可执行计划。改动原因是当前用户目标已切换为运行时沙盒风险治理，旧计划不再对应现阶段任务。

2026-03-03（R18 完成）：完成全部 4 个里程碑并通过回归。过程中修正了 `CompositionRoot` 的类/实例判定回退问题，并保留了 `RuntimeEventBridge` 的 guarded `debug.getupvalue` 预检查以满足既有契约。改动原因是保证“去除硬依赖”不破坏现有行为，并用测试闭环确认收敛效果。
