# Lua 环境合规审计

本文件记录 Lua 沙盒合规扫描与修复结果，口径以 `docs/eggy/lua_env.md` 为准。

## 范围与规则

审计范围为 `Components/`、`Manager/`、`Config/`、`Library/Monopoly/`、`Data/` 与入口脚本，不包含 `tests/`。测试脚本为本地工具，仍会使用 `io/os`。

审计规则：

- 禁用 `io`/`os`/`package`/`debug` 访问。
- 禁用 `debug.traceback`。
- 禁用 `math.random`。
- 禁用 metatable 中的 `__gc` 与 `__mode`。

## 修复摘要

- 入口由 `main.lua` 加载 `init.lua`，避免对 `package.path` 的依赖。
- RNG 默认种子不再依赖 `os.time`，由上层显式传入；EggyRuntime 使用 `GameAPI.get_timestamp()` 作为 seed。
- `Dice.roll` 强制依赖传入 RNG，移除 `math.random`。
- `Library/Monopoly/Logger.lua` 移除 `io/os` 写文件与时间格式化，改为可注入的 `timestamp_provider` 与 `time_formatter`。

## 审计结果

运行：

    lua tests/lua_env_audit.lua

输出：

    [lua-env] ok: no violations in runtime paths

## 备注

- `tests/` 下脚本继续使用 `io/os` 读取文件与输出日志；这些脚本不进入发布沙盒。
