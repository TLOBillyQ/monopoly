-- script_bootstrap.lua —— 包 runner 入口引导共享块(#320 收尾)。
--
-- 背景:5 个 tools/packages/<pkg>/runner.lua 原先各自内联一份 9 行样板
-- (_normalize_path + _module_dir + dofile bootstrap.lua + install),逐字节
-- 相同,只有 fallback 目录字符串不同。收尾把它收敛进本文件——样板逻辑
-- (normalize / match / dofile / install 的 source 选择)唯一出处在这里,
-- 每个 runner.lua 头部只剩 3 行:
--
--   local _self = debug.getinfo(1, "S").source or "@tools/packages/<pkg>/runner.lua"
--   local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
--     .. "/../../foundation/script_bootstrap.lua")
--   local bootstrap_env, bootstrap = _sb.install("tools/packages/<pkg>")
--
-- 为什么 runner 仍要自定位本文件:install 前 package.path 未装(require 不可用),
-- 且脚本可能被绝对路径从非仓根 cwd 调用——「第一块砖」只能由调用方算出的
-- 自身目录之上 dofile 到。remaining per-file 内容就是这 3 行,再无 9 行样板。
--
-- install 的 script_source 语义与原样板完全一致(#320 未改行为):
--   (arg and arg[0]) or _self —— 进程入口 arg[0] 优先(脚本/被 cli.lua 转发时
--   均为真实入口),否则退回调用方 chunk 的 source。两者 bootstrap.install
--   都能从 dirname 上溯定位 repo_root。

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/foundation/script_bootstrap.lua"
  return tostring(source):gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/foundation"
end

local _bootstrap = dofile(_module_dir() .. "/bootstrap.lua")

local sb = {}

-- install(fallback_dir, self_source) -> env, bootstrap
--   fallback_dir: 定位不到自身文件目录时的兜底(如 "tools/packages/crap");
--   self_source:  调用方 chunk 的 source(debug.getinfo(1,"S").source)。
function sb.install(fallback_dir, self_source)
  local script_source = (arg and arg[0]) or self_source
  local env = _bootstrap.install(script_source)
  return env, _bootstrap
end

return sb