-- tool_availability.lua —— 工具自举「不可用」的分类与诊断(#112)。
--
-- 背景:上游工具首次自举要打网络(git ls-remote 解析 HEAD、git clone 拉源码、
-- luarocks 拉依赖)。网络瞬时失败时,调用方曾把它和测试失败一样退 1、摘要
-- failed=1,开发者与 CI 会把断网误读成测试回归。
--
-- 三态沿用 platform_boundary(#96):不可用退 3、status=unavailable 写 stderr,
-- 本次未运行、不报通过也不报失败。仓内缺陷(锁文件缺项、配置缺失)不归这里,
-- 照旧是真实失败。
--
-- 纯演算砖:bootstrap 经 classify 按失败原因分类,网络/下载类才构造 unavailable
-- 记录作为 ensure_* 的第三返回值
-- (assert(ensure_tool(...)) 形态的调用点不受影响),入口用 message 渲染诊断。

local boundary = require("foundation.platform_boundary")

local availability = {}

availability.EXIT_CODE = boundary.UNAVAILABLE_EXIT_CODE

-- 步骤词会出现在诊断文本里(可机读)与测试断言里,不要改字面量。
local _STEPS = {
  resolve = "解析上游 HEAD(git ls-remote)",
  fetch = "拉取上游源码(git clone)",
  build = "构建安装(luarocks make,会下载 rockspec 依赖)",
  install = "安装 rock(luarocks install)",
}

function availability.unavailable(tool, step, detail)
  assert(_STEPS[step] ~= nil, "tool_availability: 未登记的自举步骤 " .. tostring(step))
  return {
    status = boundary.UNAVAILABLE,
    exit_code = availability.EXIT_CODE,
    tool = tool,
    step = step,
    detail = detail,
  }
end

-- 网络/下载类失败的输出特征(git 与 luarocks 的英文报错,小写比对)。
-- 只有命中才判不可用:上游仓库不存在、编译/构建错误说明锁定版本或源码坏了,
-- 是真实失败;认不出的报错也保守按真实失败处理(宁红勿假)。
local _NETWORK_PATTERNS = {
  "could not resolve host",
  "temporary failure in name resolution",
  "failed to connect",
  "connection timed out",
  "timed out",
  "connection reset",
  "connection refused",
  "could not read from remote repository",
  "ssl",
  "tls",
  "proxy",
  "failed downloading",
  "failed fetching",
  "error fetching",
  "could not fetch",
  "unable to download",
}

function availability.is_network_failure(detail)
  local text = tostring(detail or ""):lower()
  for _, pattern in ipairs(_NETWORK_PATTERNS) do
    if text:find(pattern, 1, true) ~= nil then
      return true
    end
  end
  return false
end

-- 按失败原因分类:网络/下载类返回不可用记录,其余返回 nil(调用方按真实失败报)。
function availability.classify(tool, step, detail)
  if availability.is_network_failure(detail) then
    return availability.unavailable(tool, step, detail)
  end
  return nil
end

-- tag 是调用方前缀(如 "spec-lane"),诊断每行都带上,便于在聚合输出里认领。
function availability.message(record, tag)
  local prefix = "[" .. tostring(tag) .. "] "
  return table.concat({
    prefix .. "status=" .. boundary.UNAVAILABLE .. " tool=" .. tostring(record.tool)
      .. " step=" .. tostring(record.step),
    prefix .. "工具 " .. tostring(record.tool) .. " 自举失败于「" .. _STEPS[record.step]
      .. "」,通常是网络不可达或瞬时失败。",
    prefix .. "本次未运行任何检查;退出码 " .. availability.EXIT_CODE .. " 表示环境不可用,不是测试/检查结论。",
    prefix .. "详情: " .. tostring(record.detail),
    prefix .. "处理: 检查网络(能否访问上游仓库)后重试;或在联网环境先跑一次同一命令,"
      .. "把工具预装进 .toolcache/luarocks。",
    "",
  }, "\n")
end

return availability
