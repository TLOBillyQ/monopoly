# Lua 环境合规扫描与清理计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md。

## 目的 / 全局视角


目标是把现有 Lua 代码与 docs/eggy/lua_env.md 的限制完全对齐，扫出不合规用法并清理到正确接口与写法。完成后，沙盒运行不再依赖被移除的库、不再依赖开发者模式特性，数值与字典用法符合限制，且通过回归测试与新增合规审计脚本验证。验证方式包括：运行审计脚本得到零违规清单、运行现有测试全通过、以及在 Eggitor 试玩时不触发沙盒限制错误。

## 进度


- [x] (2026-01-28 16:50Z) 创建计划初版，基于 docs/eggy/lua_env.md 明确扫描与修复范围。
- [ ] (2026-01-28 16:50Z) 生成 Lua 环境合规扫描报告并落盘。
- [ ] (2026-01-28 16:50Z) 清理全部不合规点并替换为正确接口。
- [ ] (2026-01-28 16:50Z) 运行审计与回归测试并记录结果。

## 意外与发现


当前暂无发现，实施中如遇到沙盒行为与预期不符，将以“观察/证据”形式补充。

## 决策日志


- 决策：先产出全量扫描报告，再逐条清理与验证。
  理由：避免遗漏与来回返工，确保修复顺序和影响范围清晰可追踪。
  日期/作者：2026-01-28 / Codex

## 结果与复盘


尚未实施，完成后在此总结修复范围、遗留风险与后续建议。

## 背景与导读


Lua 运行在 Eggy 沙盒中，部分标准库被移除且语法受限，详情见 docs/eggy/lua_env.md。代码主要在 src/，测试在 tests/，运行入口为 main.lua；适配层位于 src/adapters/。本计划要把全部 Lua 代码与沙盒限制对齐，重点关注：被移除库（io/os/package/debug）、math 的差异与 Fixed/整数范围、字符串与数字不允许隐式转换、普通 table 键仅限数字/字符串、dict() 的使用、setmetatable 受限字段、require 仅加载 script 目录模块、开发者模式仅用于 PC 编辑器试玩且不能成为依赖。这里的“合规”指在发布后的地图运行时不使用被限制的能力。

## 工作计划


先以 docs/eggy/lua_env.md 为准建立扫描清单，并用静态扫描与人工复核结合的方式产出一份合规报告（文件列表、行号、问题描述与修复方案）。随后按报告逐项修复：移除或替换被禁库调用，调整数值与字符串的显式转换，必要时把使用复杂键的 table 改成 dict() 或稳定的字符串键，修正 setmetatable 的禁用字段，确认 require 的路径与打包策略符合限制，避免逻辑依赖开发者模式功能。修复过程中新增一个轻量审计脚本作为回归防线，确保相同问题不会回流。完成后运行现有测试与新增审计脚本，并记录关键输出作为证据。

## 具体步骤


在仓库根目录读取限制说明并作为唯一口径：

    type docs\eggy\lua_env.md

进行静态扫描并初步列出可疑点，至少覆盖被移除库、debug/traceback、developer mode、setmetatable 受限字段、require 使用、math 调用等：

    rg -n "\b(io|os|package|debug)\." src tests Data -S
    rg -n "\btraceback\b|\bdebug\.traceback\b" src tests -S
    rg -n "enable_developer_mode" src tests -S
    rg -n "\bsetmetatable\b|\bgetmetatable\b" src -S
    rg -n "\brequire\b" src tests -S
    rg -n "\bmath\." src -S

针对“字符串/数字隐式转换”和“table 键类型限制”这类不易纯扫描的问题，按模块人工复核高风险路径（配置读取、网络/事件参数、存储索引、以对象做键的表），并在报告中标明触发场景与替代方案。必要时补充小范围运行时断言或类型转换，以显式方式消除隐式转换风险。

把扫描与人工复核结果整理进新文档（建议路径 docs/eggy/lua_env_audit.md），每条包含文件、行号、问题描述、修复方式与验证方式。此文档是后续清理的唯一待办清单。

按报告逐项修复代码。常见替换策略应直接写入修改位置，例如：用 traceback 代替 debug.traceback；移除 io/os/package/debug 依赖，转为已有 LuaAPI 或内部接口；对数值字符串用 tonumber/tostring 显式转换；对非字符串/数字键改为 dict() 或稳定 ID 字符串；对 setmetatable 禁用字段直接删除或改为普通 table；对 math 使用 Fixed/整数并在需要处调用 tofixed/tointeger；对欧拉角顺序变更场景在迁移逻辑中显式标注并修正。

新增或更新一个轻量审计脚本（建议 tests/lua_env_audit.lua），让它在 CI 或本地执行时能扫描并在发现违规时失败退出，覆盖至少被移除库、developer mode 和 setmetatable 限制等确定性规则。该脚本应只依赖现有 Lua 运行环境，不引入额外库。

## 验证与验收


在仓库根目录执行审计与回归测试，预期无违规且测试全通过：

    lua tests/lua_env_audit.lua
    lua tests/deps_check.lua
    lua tests/regression.lua

验收标准是：审计脚本输出无违规；回归测试全通过；Eggitor 试玩时不因沙盒限制报错，功能表现不回退。

## 可重复性与恢复


扫描与审计脚本为只读操作，可重复执行。代码修改可通过版本控制回退；若审计脚本引发误报，先记录并调整规则，再重新运行，避免直接放宽限制导致回归。

## 产物与备注


产物包括合规扫描报告（建议 docs/eggy/lua_env_audit.md）、修复后的 Lua 代码，以及新增的审计脚本（建议 tests/lua_env_audit.lua）。报告与审计脚本共同作为后续维护的基线。

## 接口与依赖


修复时只能使用 docs/eggy/lua_env.md 中允许的全局函数与库，dict() 仅在需要非字符串/数字键时使用，setmetatable 禁用 __mode 与 __gc，require 仅加载 script 目录模块，开发者模式只能用于 PC 编辑器试玩且不允许成为发布逻辑依赖。新增审计脚本应仅依赖当前项目 Lua 环境与标准测试运行方式。

本次更新：创建 Lua 环境合规扫描与清理计划初版，明确扫描口径、产物与验证流程。
