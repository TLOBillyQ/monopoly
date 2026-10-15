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

-- 按本文件所在目录 dofile 兄弟模块:bootstrap 在 package.path 装好之前就加载本文件。
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/foundation/tool_availability.lua"
  local normalized = tostring(source):gsub("\\", "/"):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/foundation"
end

local boundary = dofile(_module_dir() .. "/platform_boundary.lua")

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

-- 网络/下载类失败的输出特征(git 与 luarocks 的英文报错,小写子串比对)。
-- 只有命中才判不可用:上游仓库不存在、编译/构建错误说明锁定版本或源码坏了,
-- 是真实失败;认不出的报错也保守按真实失败处理(宁红勿假)——包括本地化
-- 报错(如中文 git),认不出就退 1,这是有意的取舍。
-- 只收具体短语:裸 "ssl"/"tls"/"proxy"/"timed out" 会把 openssl/ssl.h 编译错误、
-- 编译超时、带这些字样的文件名误判成不可用。ssh 形态的仓库不存在也带
-- "could not read from remote repository",故不收。
local _HOST_PATTERNS = {
  "could not resolve host",
  "temporary failure in name resolution",
  "connection refused",
  "connection reset",
}

-- git 传输层:主机/连接/超时/TLS/代理。
local _GIT_PATTERNS = {
  "failed to connect",
  "connection timed out",
  "operation timed out",
  "ssl certificate problem",
  "ssl_connect",
  "ssl_read",
  "ssl/tls connection failed",
  "gnutls_handshake",
  "tls handshake",
  "failed to receive handshake",
  "could not connect to proxy",
  "proxy connect aborted",
}

-- luarocks 构建/安装:只认下载类(构建期间的超时、编译错误不算)。
local _DOWNLOAD_PATTERNS = {
  "failed downloading",
  "failed fetching",
  "error fetching",
  "could not fetch",
  "unable to download",
}

local _STEP_PATTERNS = {
  resolve = { _HOST_PATTERNS, _GIT_PATTERNS },
  fetch = { _HOST_PATTERNS, _GIT_PATTERNS },
  build = { _HOST_PATTERNS, _DOWNLOAD_PATTERNS },
  install = { _HOST_PATTERNS, _DOWNLOAD_PATTERNS },
}

local function _is_network_failure(step, detail)
  local text = tostring(detail or ""):lower()
  for _, patterns in ipairs(_STEP_PATTERNS[step]) do
    for _, pattern in ipairs(patterns) do
      if text:find(pattern, 1, true) ~= nil then
        return true
      end
    end
  end
  return false
end

-- 按失败原因分类:网络/下载类返回不可用记录,其余返回 nil(调用方按真实失败报)。
function availability.classify(tool, step, detail)
  assert(_STEPS[step] ~= nil, "tool_availability: 未登记的自举步骤 " .. tostring(step))
  if _is_network_failure(step, detail) then
    return availability.unavailable(tool, step, detail)
  end
  return nil
end

-- 渲染成 platform_boundary 的不可用判定({status, exit_code, stream, message}),
-- 入口直接交 boundary.emit 写出或取 message 放进结果字段。
-- tag 是调用方前缀(如 "spec-lane"),诊断每行都带上,便于在聚合输出里认领。
function availability.verdict(record, tag)
  return boundary.unavailable_verdict(tag,
    " tool=" .. tostring(record.tool) .. " step=" .. tostring(record.step), {
      "工具 " .. tostring(record.tool) .. " 自举失败于「" .. _STEPS[record.step]
        .. "」,通常是网络不可达或瞬时失败。",
      "本次未运行任何检查;退出码 " .. availability.EXIT_CODE .. " 表示环境不可用,不是测试/检查结论。",
      "详情: " .. tostring(record.detail),
      "处理: 检查网络(能否访问上游仓库)后重试;或在联网环境先跑一次同一命令,"
        .. "把工具预装进 .toolcache/luarocks。",
    })
end

function availability.message(record, tag)
  return availability.verdict(record, tag).message
end

return availability
