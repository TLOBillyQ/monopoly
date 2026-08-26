-- cli_command_table_guard 配置(#316 / #300 Q4 决议):tools/cli.lua 顶层封闭
-- tools/cli.lua 封闭命令表之外、允许存在于 tools/packages/ 但不挂路由的
-- 非路由包白名单。每个条目注明不路由的理由;包迁/新包落地时同步维护——
-- 条目所指的包一旦挂进 commands 表或目录消失,guard 会报 stale 要求销账。
return {
  non_routed_packages = {
    "coverage",           -- 覆盖率车道实现件,由 verify --full 包内消费,非用户子命令
    "encoding",           -- 编码检查实现件,由 verify encoding 车道直接调入口,非子命令
    "luaunit_runner",     -- 底层运行器，不进封闭命令集（包内 cli 供 verify/coverage/spec_lane 消费）
  },
}
