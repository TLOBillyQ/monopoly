local dsl = require("packages.acceptance.step_dsl")
local replay = require("src.ui.state.item_slot_highlight_replay")
local coord = require("src.ui.coord.item_slot_highlight_replay_coord")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")
local logger = require("src.foundation.log")

-- 可用槽位高亮重放域绑定(#594):判定走真实 ui.state 模块,宿主投递走真实
-- coord,只把宿主出口(client role / send_ui_custom_event)与 logger 换成
-- 读 world 的假实现,把事件名序列与投递目标捕获进 world。

local _PLAYER_MISSING = "无展示玩家"
local _ROLE_MISSING = "无本机角色"

local function _world(w)
  if w.replay_world == nil then
    w.replay_world = {
      state = {},
      events = {},
      targets = {},
      warns = {},
      send_fails = false,
    }
  end
  return w.replay_world
end

-- 「本机角色1展示玩家1」/「本机角色字符串1展示玩家1」/「无本机角色展示玩家1」
-- 等表述解析成结构化视角。字符串变体刻意保留字符串身份,验证归一化。
-- 一侧身份:缺失 → nil;「字符串1」→ 字符串 "1"(刻意不归一,验证归一化);
-- 否则整数。两侧规则相同,只是各自的缺失表述与前缀不同。
local function _parse_identity(text, missing, prefix)
  if text == missing then
    return nil
  end
  local body = (tostring(text):gsub("^" .. prefix, ""))
  local as_text = body:match("^字符串(%d+)$")
  if as_text ~= nil then
    return as_text
  end
  return math.tointeger(body)
end

local function _parse_perspective(text)
  local role_part, player_part = text:match("^(.-)展示玩家(.*)$")
  if role_part == nil then
    role_part, player_part = text:match("^(.-)(" .. _PLAYER_MISSING .. ")$")
  end
  return {
    role_id = _parse_identity(role_part, _ROLE_MISSING, "本机角色"),
    display_player_id = _parse_identity(player_part, _PLAYER_MISSING, ""),
  }
end

-- 「可,不可,可,不可,不可」→ 布尔数组;「无槽位快照」→ nil。
local function _parse_snapshot(text)
  if text == "无槽位快照" then
    return nil
  end
  local slots = {}
  for token in tostring(text):gmatch("[^,]+") do
    slots[#slots + 1] = (token:gsub("%s", "") == "可")
  end
  return slots
end

-- 「该展示视角」= 上一步记住的视角;「展示视角本机角色1展示玩家1」= 就地解析。
local function _resolve_perspective(w, text)
  if text == "该展示视角" then
    return _world(w).perspective
  end
  return _parse_perspective((tostring(text):gsub("^展示视角", "")))
end

-- 宿主一次发送:失败即抛(由 coord 的 pcall 兜住),成功记事件名与投递目标。
local function _record_send(world, name, target)
  if world.send_fails then error("host highlight send failed") end
  world.events[#world.events + 1] = name
  world.targets[#world.targets + 1] = target
end

-- 宿主出口补丁窗口:跑完立即还原(失败也先还原再抛)。
local function _with_host(w, fn)
  local world = _world(w)
  local patches = {
    { runtime_ui, "get_client_role", function() return world.client_role end },
    { ui_events, "send_to_role", function(role, name)
      return _record_send(world, name, "角色" .. tostring(role and role.id))
    end },
    { ui_events, "send_to_all", function(name)
      return _record_send(world, name, "全体")
    end },
    { logger, "warn", function(...) world.warns[#world.warns + 1] = table.concat({ ... }, " ") end },
  }
  local originals = {}
  for i, patch in ipairs(patches) do
    originals[i] = patch[1][patch[2]]
    patch[1][patch[2]] = patch[3]
  end
  local ok, result = pcall(fn)
  for i = #patches, 1, -1 do patches[i][1][patches[i][2]] = originals[i] end
  if not ok then error(result) end
  return result
end

-- 一次完整观察:判定计划 + 投递宿主动画,与生产链路同序。
local function _observe(w, perspective, snapshot)
  local world = _world(w)
  world.client_role = perspective.role_id ~= nil and { id = perspective.role_id } or nil
  return _with_host(w, function()
    local plan = replay.plan_refresh(world.state, perspective, snapshot)
    world.last_plan = plan
    world.last_delivery_ok = coord.deliver(plan, snapshot)
    return plan
  end)
end

-- 建立「已重放」前置:先观察一次并清空捕获,让断言只看后续观察。
local function _seed_replayed(w, perspective, snapshot_text)
  local world = _world(w)
  _observe(w, perspective, _parse_snapshot(snapshot_text))
  world.events, world.targets, world.warns = {}, {}, {}
  return true
end

local function _expected_memory(text)
  if text == "空集合" then return "" end
  if text == "无记忆" then return nil end
  return text
end

local function _count_events(world, name)
  local count = 0
  for _, event in ipairs(world.events) do
    if event == name then count = count + 1 end
  end
  return count
end

local function _has_prefix(world, prefix)
  for _, event in ipairs(world.events) do
    if event:sub(1, #prefix) == prefix then return true end
  end
  return false
end

-- 逗号分隔的期望串 → 去空白的数组(Lua 字符类按字节,只能拿 ASCII 逗号切)。
local function _split_trimmed(text)
  local parts = {}
  for token in tostring(text):gmatch("[^,]+") do
    parts[#parts + 1] = (token:gsub("^%s*(.-)%s*$", "%1"))
  end
  return parts
end

-- 场景 013 的解冻事件:发出槽位命令,或该待决选择被关闭。其余「发生…」句面
-- 属于场景 002 的窗口翻新,不是生命周期事件。
local function _unfreeze_event(text)
  if text:find("发出槽位命令", 1, true) then
    return { kind = "slot_command" }
  end
  local choice_id = text:match("^待决选择(.-)因.-关闭$")
  if choice_id ~= nil then
    return { kind = "choice_released", choice_id = choice_id }
  end
  return nil
end

-- 场景 010 的非法输入表:前两种缺参形状两操作共用,第三种各自专属。
local _VIEW = { role_id = 1, display_player_id = 1 }
local _THIRD = {
  apply_lifecycle = { { kind = "slot_command", choice_id = "c1" }, ["未知生命周期事件种类"] = { kind = "未知" } },
  plan_refresh = { { true }, ["非布尔槽位数组"] = { "可" } },
}

local function _invalid_call(operation, input)
  local call, spec = replay[operation], _THIRD[operation]
  if call == nil or spec == nil then return nil end
  if input == "缺失展示状态" then return function() call(nil, _VIEW, spec[1]) end end
  if input == "缺失展示视角" then return function() call({}, nil, spec[1]) end end
  local own = spec[input]
  if own == nil then return nil end
  return function() call({}, _VIEW, own) end
end

return dsl.steps({
  ["玩家背包上限为5格（高亮重放）"] = function(w) _world(w) return true end,

  ["展示视角为{视角}"] = function(w, a)
    _world(w).perspective = _parse_perspective(a["视角"])
    return true
  end,
  ["{视角}尚无高亮重放记忆"] = function(w, a)
    local world = _world(w)
    world.perspective = _resolve_perspective(w, a["视角"])
    return dsl.eq(replay.remembered_signature(world.state, world.perspective), nil, "高亮重放记忆")
  end,
  ["{视角}已重放槽位快照{槽位快照}"] = function(w, a)
    local world = _world(w)
    world.perspective = _resolve_perspective(w, a["视角"])
    return _seed_replayed(w, world.perspective, a["槽位快照"])
  end,
  ["宿主高亮事件发送失败"] = function(w) _world(w).send_fails = true return true end,

  -- 「…在冻结期间观察到…」是同一次观察,只是标记为中间步骤:它的计划与事件
  -- 不该被后续断言看到,故观察后清空捕获(否则会读到中间态而非解冻后的判定)。
  ["{视角}观察到槽位快照{槽位快照}"] = function(w, a)
    local world = _world(w)
    local view, interim = a["视角"], false
    local head = view:match("^(.-)在冻结期间$")
    if head ~= nil then
      view, interim = head, true
    end
    world.perspective = _resolve_perspective(w, view)
    _observe(w, world.perspective, _parse_snapshot(a["槽位快照"]))
    if interim then
      world.events, world.targets = {}, {}
    end
    return true
  end,
  -- 「发生<X>」承两类事件,按内容分流(场景 002 的翻新 vs 场景 013 的解冻):
  --   解冻事件 → 投递对应生命周期,记忆不动;
  --   翻新事件 → choice_id 翻新、窗口开关、阶段推进、同槽换卡都不进签名,用一次
  --   「集合不变」的中间观察真实驱动链路,证明既不改记忆也不产生宿主事件。
  ["发生{事件}"] = function(w, a)
    local world = _world(w)
    local text = a["事件"]
    local before = replay.remembered_signature(world.state, world.perspective)
    local unfreeze = _unfreeze_event(text)
    if unfreeze ~= nil then
      replay.apply_lifecycle(world.state, world.perspective, unfreeze)
    else
      _observe(w, world.perspective, _parse_snapshot("可,不可,可,不可,不可"))
    end
    world.events, world.targets = {}, {}
    return dsl.eq(replay.remembered_signature(world.state, world.perspective), before,
      tostring(text) .. " 不改变记忆")
  end,
  -- #595 冻结生命周期。三种句面都投递 apply_lifecycle,只是事件种类不同:
  -- 确认 → confirm_item_use;槽位命令 → slot_command;各种关闭 → choice_released
  -- (取消/结束/替换统一归一为「带选择标识的关闭」,场景 018)。
  ["{视角}确认使用待决选择{待决选择}"] = function(w, a)
    local world = _world(w)
    world.perspective = _resolve_perspective(w, a["视角"])
    replay.apply_lifecycle(world.state, world.perspective,
      { kind = "confirm_item_use", choice_id = a["待决选择"] })
    return true
  end,
  -- 规则结算(接受/拒绝)刻意不进展示状态:槽位命令一发出就解冻,与规则是否
  -- 采纳该次用卡无关(场景 015)。
  ["展示视角{视角}发出槽位命令且规则结算为{规则结算}"] = function(w, a)
    local world = _world(w)
    replay.apply_lifecycle(world.state, _parse_perspective(a["视角"]),
      { kind = "slot_command" })
    return true
  end,
  ["展示视角{视角}发出槽位命令"] = function(w, a)
    local world = _world(w)
    replay.apply_lifecycle(world.state, _parse_perspective(a["视角"]),
      { kind = "slot_command" })
    return true
  end,
  ["待决选择{待决选择}因{关闭来源}关闭"] = function(w, a)
    local world = _world(w)
    replay.apply_lifecycle(world.state, world.perspective,
      { kind = "choice_released", choice_id = a["待决选择"] })
    return true
  end,
  ["高亮重放公开操作为{公开操作}"] = function(w, a)
    _world(w).operation = a["公开操作"]
    return true
  end,
  ["调用方传入{非法输入}"] = function(w, a)
    local world = _world(w)
    world.invalid_call = _invalid_call(world.operation, a["非法输入"])
    return dsl.truthy(world.invalid_call, "非法输入构造 " .. tostring(a["非法输入"]))
  end,

  ["高亮计划为{高亮计划}"] = function(w, a)
    return dsl.eq(_world(w).last_plan, a["高亮计划"], "高亮计划")
  end,
  ["{视角}记忆的可选槽位编号集合为{记忆集合}"] = function(w, a)
    local world = _world(w)
    return dsl.eq(replay.remembered_signature(world.state, _resolve_perspective(w, a["视角"])),
      _expected_memory(a["记忆集合"]), "记忆的可选槽位编号集合")
  end,
  ["宿主未收到任何高亮事件"] = function(w)
    return dsl.eq(#_world(w).events, 0, "宿主高亮事件数")
  end,
  ["宿主收到{次数:int}次\"重置高亮\""] = function(w, a)
    return dsl.eq(_count_events(_world(w), "重置高亮"), a["次数"], "全局重置高亮次数")
  end,
  -- 逐槽「清除」= 重置高亮道具槽位牌N,逐槽「高亮」= 高亮道具槽位牌N。
  ["宿主未收到任何逐槽{逐槽种类}事件"] = function(w, a)
    local kind = a["逐槽种类"]
    local prefix = (kind == "清除" and "重置高亮" or "高亮") .. "道具槽位牌"
    return dsl.eq(_has_prefix(_world(w), prefix), false, "逐槽" .. kind .. "事件")
  end,
  ["宿主高亮事件顺序为{宿主事件顺序}"] = function(w, a)
    return dsl.eq(table.concat(_world(w).events, ", "),
      table.concat(_split_trimmed(a["宿主事件顺序"]), ", "), "宿主高亮事件顺序")
  end,
  ["宿主高亮事件投递给{投递目标}"] = function(w, a)
    return dsl.eq(_world(w).targets[1], a["投递目标"], "宿主高亮事件投递目标")
  end,
  ["保留宿主高亮事件发送失败诊断"] = function(w)
    local world = _world(w)
    return dsl.all(
      function() return dsl.eq(#world.warns >= 1, true, "发送失败诊断条数") end,
      function() return dsl.eq(world.last_delivery_ok, false, "投递结果") end)
  end,
  ["未自动重试宿主高亮事件"] = function(w)
    -- 失败路径只尝试一轮:没有事件被记为送达,也没有第二条诊断。
    local world = _world(w)
    return dsl.all(
      function() return dsl.eq(#world.events, 0, "已送达事件数") end,
      function() return dsl.eq(#world.warns, 1, "诊断条数(重试会多一条)") end)
  end,
  ["游戏交互未被阻塞"] = function(w)
    -- 宿主抖动不得把后续观察打断:失败后仍能正常判定下一次计划。
    local world = _world(w)
    world.send_fails = false
    local plan = _observe(w, world.perspective, { true, true, false, false, false })
    return dsl.eq(plan, replay.PLAN_REPLAY, "失败后仍可继续判定")
  end,
  ["该调用断言失败"] = function(w)
    local ok = pcall(_world(w).invalid_call)
    return dsl.eq(ok, false, "公开操作断言")
  end,
}, { name = "item_slot_highlight_replay" })
