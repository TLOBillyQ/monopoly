-- packages/spec_lane/cli.lua —— spec-lane 子命令(wayfinder #306 包迁落地)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现:同一进程内直调本包 spec_lane.lua 的 main(它被 require 时返回纯接口
-- 模块;当脚本被直调时自行 os.exit)。usage 真源 = spec_lane_args.usage(),
-- spec_lane.main 的 --help 分支与顶层 cli.lua 转发共用同一文本。
local M = {}

local lane_args = require("packages.spec_lane.spec_lane_args")
local spec_lane = require("packages.spec_lane.spec_lane")

function M.usage()
  return lane_args.usage()
end

function M.main(args, env)
  return spec_lane.main(args or {})
end

return M
