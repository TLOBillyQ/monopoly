-- 卡牌展示广播的公开接缝(ADR 0017,#165):acceptance step 观察
-- 「机会卡弹窗 / 道具获得展示 / 破产文案」真实链路时经此 port,不直挖
-- rules 内部模块。本文件是纯契约声明(#329):不反向依赖实现,实现由装配侧
-- configure 注入(host_install / 测试基线 / acceptance step 绑定)。签名与
-- 被转发实现同形,本模块不叠加任何规则结论。
local card_reveal = {}
local configured_impl = nil

local function _assert_impl_shape(impl)
  assert(type(impl) == "table", "invalid card_reveal implementation")
  assert(type(impl.push_land_popup) == "function", "card_reveal implementation missing push_land_popup")
  assert(type(impl.queue_gain_reveal) == "function", "card_reveal implementation missing queue_gain_reveal")
  assert(type(impl.bankruptcy_text) == "function", "card_reveal implementation missing bankruptcy_text")
  return impl
end

local function _resolve_impl()
  if configured_impl == nil then
    return nil
  end
  return configured_impl
end

function card_reveal.configure(impl)
  configured_impl = _assert_impl_shape(impl)
end

function card_reveal.reset_for_tests()
  configured_impl = nil
end

-- 车道守卫用:共享测试基线要求实现处于已配置态;spec teardown 拆到未配置态后
-- 不装回会让同进程后续 suite 撞「missing card_reveal implementation」。
function card_reveal.is_configured()
  return configured_impl ~= nil
end

-- 机会卡等地块弹窗广播(effect_chance 执行器对 land presenter 的真实调用面)。
function card_reveal.push_land_popup(game, title, text, opts)
  return assert(_resolve_impl(), "missing card_reveal implementation").push_land_popup(game, title, text, opts)
end

-- 道具获得展示载荷入队(道具地块 / 偷窃结算的真实产出链路)。
function card_reveal.queue_gain_reveal(game, player, item_id, opts)
  return assert(_resolve_impl(), "missing card_reveal implementation").queue_gain_reveal(game, player, item_id, opts)
end

-- 破产展示文案(kind=bankruptcy 载荷的 text 单源)。
function card_reveal.bankruptcy_text(player, opts)
  return assert(_resolve_impl(), "missing card_reveal implementation").bankruptcy_text(player, opts)
end

return card_reveal

--[[ mutate4lua-manifest
version=4
projectHash=ccbcd8cbd79845f3
scope.0.id=chunk:src/rules/ports/card_reveal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=54
scope.0.semanticHash=e6af97d628ca1a8c
scope.1.id=function:_assert_impl_shape
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=e2dbb62243115b84
scope.2.id=function:_resolve_impl
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=710cb48908ddcc1c
scope.3.id=function:card_reveal.configure
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=26
scope.3.semanticHash=4afb02f78251fcb2
scope.4.id=function:card_reveal.reset_for_tests
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=f308d8708726be18
scope.5.id=function:card_reveal.is_configured
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=70efc1221c5d6d62
scope.6.id=function:card_reveal.push_land_popup
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=41
scope.6.semanticHash=360776c78d632b1f
scope.7.id=function:card_reveal.queue_gain_reveal
scope.7.kind=function
scope.7.startLine=44
scope.7.endLine=46
scope.7.semanticHash=360776c78d632b1f
scope.8.id=function:card_reveal.bankruptcy_text
scope.8.kind=function
scope.8.startLine=49
scope.8.endLine=51
scope.8.semanticHash=aba9250a8c6b104f
]]
