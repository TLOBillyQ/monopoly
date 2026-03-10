# 收紧启动策略到发布默认

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件位于 `.agents/plan.md`，维护时必须遵循 `.agents/harness/PLANS.md`。

## 目的 / 全局视角

当前启动策略里保留了多条开发态 / QA / profile rotation / AI mode 分支，实际运行容易偏离正式发布行为。此次调整后，启动层只保留两件事：读取启动 profile，以及在人数不足时补齐 AI 槽位。默认行为统一按发布模式执行，避免本地或调试环境再走额外分支。可见证明是：startup policy 永远返回 release 默认；真实玩家默认保持手动；只有补位产生的 synthetic player 会被标记为 AI。

## 进度

- [x] (2026-03-10 11:12Z) 清理 `startup_policy.lua`：移除 release/dev、AI mode、profile rotation、force non-P1 AI 等分支，仅保留 startup profile 解析与 release 默认。
- [x] (2026-03-10 11:14Z) 清理 `app/init.lua`：去掉与已删除分支对应的日志与启动装配参数。
- [x] (2026-03-10 11:16Z) 清理 `game_startup.lua`：删除真实玩家 AI 覆盖分支，只保留 synthetic 补位玩家的 AI 标记。
- [x] (2026-03-10 11:20Z) 重写 `tests/suites/runtime/startup_release.lua`，仅覆盖保留后的行为边界。
- [x] (2026-03-10 11:22Z) 运行 `startup_release`、`gameplay_items_startup`、`gameplay_timeout_and_auto_runner` 回归，共 35 个用例通过。

## 意外与发现

- 观察：人数不足补 AI 的真实入口不在 `startup_policy.lua`，而在 `game_startup.lua` 组装 `role_roster` 后把 synthetic 槽位写入 `ai` map。
  证据：`_build_startup_ai_map()` 即使没有真实玩家 AI 覆盖逻辑，也会继续给 `synthetic == true` 的角色写入 `ai[index]` 和 `ai[role.role_id]`。
- 观察：`gameplay_rules.test_force_non_p1_ai` 已经没有调用方，保留会误导后续维护者。
  证据：清理启动分支后，仓库内不再有对该字段的读取。

## 决策日志

- 决策：`startup_policy.resolve()` 固定返回 `release_mode = true`。
  理由：用户要求“默认按发布来”，最直接且可执行的做法是把启动层默认值统一收敛到发布态。
  日期/作者：2026-03-10 / OpenCode
- 决策：继续允许 `STARTUP_TEST_PROFILE` 覆盖 `profile_name`。
  理由：这仍属于“启动配置”，且不会重新引入 dev/release 行为分叉。
  日期/作者：2026-03-10 / OpenCode
- 决策：删除真实玩家非 P1 自动托管入口，只保留人数不足时 synthetic 玩家补 AI。
  理由：这是用户明确要求保留的唯一 AI 分支，也能避免再次出现真实玩家被默认托管的问题。
  日期/作者：2026-03-10 / OpenCode

## 结果与复盘

本次修改已经落地并通过相关回归。启动层现在更接近“无歧义的发布装配”：只有 profile 选择和 synthetic 补位 AI 两个结果导向分支。经验上，这类启动策略如果保留过多测试/调试开关，很容易把运行时行为变成“看环境猜分支”；收紧到发布默认后，更适合实机排查和稳定联调。

## 背景与导读

`src/app/bootstrap/startup_policy.lua` 负责把 `_G` 启动参数整理为启动策略对象。`src/app/init.lua` 会读取这个策略并装配 `game_startup.build_state(...)`。`src/app/bootstrap/game_startup.lua` 会先解析实际在线角色，再在人数不足时补 synthetic 槽位，并把这些 synthetic 槽位标记为 AI。过去的复杂度主要来自 startup policy 里混入了 release/dev、QA profile override、profile rotation、all-except-local-human、force non-P1 AI 等多条分支；本次已全部收掉。

## 工作计划

先把 `startup_policy.lua` 缩到最小：只认 `STARTUP_TEST_PROFILE`，其他环境参数一律不再参与分支。然后在 `app/init.lua` 中删除所有已失效字段的日志和参数透传，避免调用方继续依赖它们。最后把 `game_startup.lua` 的 AI map 生成逻辑缩成“只有 synthetic 玩家才是 AI”，并同步重写 runtime 启动回归测试，使测试只验证保留下来的行为边界。

## 具体步骤

在仓库根目录执行：

    lua -e "require('tests.bootstrap').install_package_paths(); local harness=require('TestHarness'); harness.run_all({require('suites.runtime.startup_release'), require('suites.gameplay.gameplay_items_startup'), require('suites.gameplay.gameplay_timeout_and_auto_runner')}, {mode='dev', capture_logs=true})"

预期输出：

    All regression checks passed (35)

如需查看本次修改范围，可执行：

    git diff -- src/app/bootstrap/startup_policy.lua src/app/init.lua src/app/bootstrap/game_startup.lua src/core/config/gameplay_rules.lua tests/suites/runtime/startup_release.lua

## 验证与验收

验收一：`startup_policy.resolve()` 在未设置任何发布标记时，仍返回 `release_mode == true`，并默认使用 `default` profile。

验收二：当 `STARTUP_TEST_PROFILE` 被设置时，startup policy 仍能返回对应 profile 名称。

验收三：当没有真实玩家角色时，startup 仍会补满 4 个 synthetic 槽位，并把它们全部标记为 AI。

验收四：当 4 个真实玩家都存在时，`created_opts.ai` 必须为空，说明真实玩家默认不再被启动策略改写成 AI。

## 可重复性与恢复

本次改动只影响 Lua 源码与测试，可重复执行。若需要恢复旧的复杂启动策略，必须同时回滚 `startup_policy.lua`、`app/init.lua`、`game_startup.lua` 和 `startup_release.lua`，否则调用方会和策略对象结构不一致。

## 产物与备注

关键产物：

    src/app/bootstrap/startup_policy.lua
    src/app/init.lua
    src/app/bootstrap/game_startup.lua
    tests/suites/runtime/startup_release.lua

## 接口与依赖

`startup_policy.resolve(globals)` 现在只保证返回：

    {
      release_mode = true,
      profile_name = <default 或 STARTUP_TEST_PROFILE>
    }

`game_startup.build_state()` 仍接受 `opts` 表，但当前只依赖 `profile_name`。synthetic 玩家补位逻辑继续依赖 `runtime_ports.resolve_roles()`、`runtime_ports.rng_next_int()` 与 `Config.runtime_refs` 中的 AI 头像资源。

修改说明：2026-03-10 OpenCode 将启动策略收紧为发布默认，并删除除启动 profile 与 synthetic 补 AI 之外的分支，原因是用户要求去除调试/测试态分叉，避免真实玩家启动行为再偏离发布态。
