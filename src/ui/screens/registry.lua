-- 选择屏注册表：每个 Screen 深模块 require 时自注册，共享派发/工厂表
-- (node_ops.build_choice_screens / choice_openers._screen_openers /
--  routes.canvas_builders / choice_helpers.screen_canvases) 统一向此委托。
-- 引入此 seam 后，新增/迁移一个屏只动它自己的文件 + 下方 require 清单，
-- 屏与屏之间零重叠写 —— 这是「逐屏并行」成立的前提。
--
-- 为避免 registry 与各 Screen 模块在 require 期互相等待，本模块不主动 `_load_all`；
-- 首次调用任意聚合 API 时才惰性加载清单中的屏模块，此时 registry 已就绪。
local registry = {}

local _screens = {}       -- 按注册序保留（route spec 拼接需保序）
local _by_key = {}
local _loaded = false

function registry.register(screen)
  assert(type(screen) == "table" and type(screen.key) == "string", "screen needs a string key")
  assert(_by_key[screen.key] == nil, "duplicate screen key: " .. screen.key)
  _screens[#_screens + 1] = screen
  _by_key[screen.key] = screen
end

-- 强制加载所有屏模块（它们在 require 时自注册）。清单是唯一的 append-only 共享点。
local function _ensure_loaded()
  if _loaded then
    return
  end
  _loaded = true
  require("src.ui.screens.target_choice")
  require("src.ui.screens.remote_choice")
  require("src.ui.screens.player_choice")
  require("src.ui.screens.secondary_confirm")
end

function registry.build_choice_screens()
  _ensure_loaded()
  local out = {}
  for _, s in ipairs(_screens) do
    out[s.key] = s.descriptor()
  end
  return out
end

function registry.opener_for(key)
  _ensure_loaded()
  local s = _by_key[key]
  return s and s.open or nil
end

function registry.canvas_for(key)
  _ensure_loaded()
  local s = _by_key[key]
  return s and s.canvas or nil
end

function registry.build_route_specs(state)
  _ensure_loaded()
  local specs = {}
  for _, s in ipairs(_screens) do
    if s.build_route_specs then
      for _, spec in ipairs(s.build_route_specs(state) or {}) do
        specs[#specs + 1] = spec
      end
    end
  end
  return specs
end

return registry

--[[ mutate4lua-manifest
version=2
projectHash=75b573424ff7d10e
scope.0.id=chunk:src/ui/screens/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=69
scope.0.semanticHash=0e5893bd95e5169e
scope.1.id=function:registry.register:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=20
scope.1.semanticHash=812ebdf36665085b
scope.2.id=function:_ensure_loaded:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=32
scope.2.semanticHash=505d00db98d5db79
scope.3.id=function:registry.opener_for:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=47
scope.3.semanticHash=c1ba9c193a95a031
scope.4.id=function:registry.canvas_for:49
scope.4.kind=function
scope.4.startLine=49
scope.4.endLine=53
scope.4.semanticHash=d113a39549f6ccae
]]
