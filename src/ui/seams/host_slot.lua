-- 宿主能力 port 的槽工厂：ui 侧只声明「函数名 + 未装配默认值」，实现表由 app
-- 装配时由 app/host_install.lua 经 configure 注入（#250）。未装配时各函数退回默认值，
-- 语义对齐 src/host 在无 runtime context 时的降级返回。
local host_slot = {}

function host_slot.new(spec)
  local slot = {}
  local impl = nil
  local names = {}

  function slot.configure(new_impl)
    impl = new_impl
  end

  function slot.reset_for_tests()
    impl = nil
  end

  function slot.is_configured()
    return impl ~= nil
  end

  for _, entry in ipairs(spec) do
    local name = entry.name
    local default = entry.default
    names[#names + 1] = name
    slot[name] = function(...)
      local fn = impl and impl[name] or nil
      if type(fn) ~= "function" then
        return default
      end
      return fn(...)
    end
  end

  -- 声明名单单一真源：聚合面（host_runtime）据此派生逐名转发，不再手写清单。
  -- 返回副本，消费方改动不回污染槽内部状态。
  function slot.declared_names()
    local copy = {}
    for i = 1, #names do
      copy[i] = names[i]
    end
    return copy
  end

  return slot
end

return host_slot

--[[ mutate4lua-manifest
version=4
projectHash=674db3815647bb3c
scope.0.id=chunk:src/ui/seams/host_slot.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=30633ba370cbb761
scope.1.id=function:host_slot.new
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=47
scope.1.semanticHash=4001154b3cfc9a17
scope.2.id=function:slot.configure
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=139af97e09c42e84
scope.3.id=function:slot.reset_for_tests
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=f308d8708726be18
scope.4.id=function:slot.is_configured
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=21
scope.4.semanticHash=70efc1221c5d6d62
scope.5.id=function:slot.name
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=33
scope.5.semanticHash=2b82503b83d1c8ba
scope.6.id=function:slot.declared_names
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=44
scope.6.semanticHash=b2bda7fcc245c4d8
]]
