--- luacov 配置单源；收集侧与 crap 消费侧都从这里读取。
---
--- 覆盖率引擎为 luacov 0.17.0-1(经上游 rockspec 依赖带入 luarocks tree),本表是
--- include/exclude/includeuntestedfiles 口径的唯一真源:
---   - luaunit_runner `-c` 在 LUACOV_CONFIG 未设时回退读它(luacov 自身查找顺序
---     即 LUACOV_CONFIG -> .luacov);
---   - coverage.lua per-shard/per-merged 临时 config 从这里派生,只覆写 statsfile;
---   - crap4lua 的 luacov adapter(tools/packages/crap/luacov_adapter.lua)顶层 init
---     时也读它,使 spec 加载期行与用例行同口径入账。
---
--- 语义与 luacov 0.17 的 config 表逐字段等价(statsfile/reportfile/runreport/
--- deletestats/codefromstrings/include/exclude/includeuntestedfiles)。
---
--- NOTE: luacov keys stats by the path used at load time (may be absolute or
--- relative with ./ prefix). 模式一律 UNANCHORED,同时匹配 "src/foundation/..."
--- 与 "/abs/.../src/foundation/..."。coverage.lua 聚合前把路径规范化到 repo 相对。
return {
  include = {
    "src/foundation/", "src/rules/", "src/turn/",
    "src/state/", "src/player/", "src/computer/",
  },
  exclude = {
    "src/app/", "src/host/", "src/ui/", "src/config/",
    "tests/", "test/", "tools/", "vendor/",
    "/usr/", "/%.luarocks/",
  },
  -- 6 个 tier 目录中零命中文件也进报告(诚实分母)。luacov 0.17 的
  -- includeuntestedfiles 走自带 dirtree walker + lfs(tree 中已有 luafilesystem)。
  includeuntestedfiles = {
    "src/foundation", "src/rules", "src/turn",
    "src/state", "src/player", "src/computer",
  },
  statsfile  = "build/luacov.stats.out",
  reportfile = "build/luacov.report.out",
  deletestats = false,    -- 跨 profile 运行累加(不删既有 stats)
  runreport   = false,    -- coverage.lua 显式 shell-out reporter
  codefromstrings = false,
}
