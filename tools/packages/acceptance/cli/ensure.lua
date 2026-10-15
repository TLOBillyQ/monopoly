-- cli/ensure.lua —— acceptance 显式入口(parser / generator / ir_dry)的工具自举
-- 三态判定收口(#114)。
--
-- 这三个入口原先各自 assert(bootstrap.ensure_tool(...)):断网时抛 Lua 错误退 1,
-- 与真实失败不可区分(#112 只接了 spec-lane 与 lint)。本模块是它们的唯一判定处,
-- 语义沿用 foundation.tool_availability(#112)/ platform_boundary(#96) 三态:
--   * 网络/下载类失败(ensure_tool 第三返回值)→ 不可用:退 3、stderr 打
--     status=unavailable tool=acceptance4lua step=<步>,未运行、不冒充检查结论;
--   * 仓内缺陷(锁文件缺项、上游仓库不存在、编译错误)→ 照旧真实失败退 1。
--
-- 纯演算砖:不写终端、不起进程;入口把返回的结果表写出并以其 code 退出。

local availability = require("foundation.tool_availability")

local ensure = {}

-- 跑一次 acceptance4lua 自举判定。options.ensure_tool 是注入缝(默认
-- foundation.bootstrap.ensure_tool),测试喂三态即可;options.tag 是诊断前缀
-- (如 "acceptance-parser"),出现在 status= 行首便于聚合输出里认领。
-- 返回 true 表示工具就绪;否则返回入口结果表:
--   不可用   → { code = 3, stdout = "", stderr = <诊断>, status = "unavailable" }
--   真实失败 → { code = 1, stdout = "", stderr = <err 文本> }
function ensure.acceptance4lua(env, options)
  options = options or {}
  local ensure_tool = options.ensure_tool or require("foundation.bootstrap").ensure_tool
  local ok, err, unavailable = ensure_tool("acceptance4lua", env)
  if unavailable ~= nil then
    local verdict = availability.verdict(unavailable, options.tag or "acceptance")
    return { code = verdict.exit_code, stdout = "", stderr = verdict.message,
      status = verdict.status }
  end
  if not ok then
    return { code = 1, stdout = "", stderr = tostring(err) .. "\n" }
  end
  return true
end

return ensure
