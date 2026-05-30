local logger = require("src.foundation.log")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local gateway = {}

local runtime_field = "__market_paid_runtime"
local panel_show_seconds = 10.0

local function _new_runtime()
  return {
    goods_id_by_product_id = {},
    product_id_by_goods_id = {},
    warned_missing_by_product_id = {},
    registered_role_ids = {},
    pending_by_role_id = {},
    on_purchase = nil,
    setup_done = false,
  }
end

local function _runtime(game)
  local rt = game[runtime_field]
  if not rt then
    rt = _new_runtime()
    game[runtime_field] = rt
  end
  return rt
end

local function _resolve_role(player)
  if not player or player.id == nil then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player.id)
  if not ok then
    return nil
  end
  return role
end

local function _resolve_role_id(player, role)
  if role and type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid)
    if ok and role_id ~= nil then
      return role_id
    end
    logger.warn("market paid role_id resolve failed", "player_id=" .. tostring(player and player.id or nil))
  end
  return player and player.id or nil
end

local function _mapping_warning_already_seen(rt, product_id)
  if rt.warned_missing_by_product_id[product_id] then
    return true
  end
  return false
end

local function _warn_mapping_missing_once(rt, entry, reason)
  local product_id = entry.product_id
  if _mapping_warning_already_seen(rt, product_id) then
    return
  end
  rt.warned_missing_by_product_id[product_id] = true
  logger.warn(
    "market paid goods mapping missing:",
    "product_id=" .. tostring(product_id),
    "name=" .. tostring(entry and entry.name or ""),
    "currency=" .. tostring(entry and entry.currency or ""),
    "reason=" .. tostring(reason or "mapping_missing")
  )
end

local function _load_goods_list()
  if GameAPI == nil then
    return nil
  end
  local get_goods_list = GameAPI.get_goods_list
  if type(get_goods_list) ~= "function" then
    return nil
  end
  local ok, list = pcall(get_goods_list)
  if not ok then
    return nil
  end
  if type(list) ~= "table" then
    return nil
  end
  return list
end

local function _record_goods_name(goods_by_name, duplicate_name, goods)
  local name = goods and goods.name or nil
  if type(name) ~= "string" then
    return
  end
  if name == "" then
    return
  end
  if goods_by_name[name] and goods_by_name[name] ~= goods then
    duplicate_name[name] = true
    return
  end
  goods_by_name[name] = goods
end

local function _index_goods_by_name(goods_list)
  local goods_by_name = {}
  local duplicate_name = {}
  if type(goods_list) == "table" then
    for _, goods in ipairs(goods_list) do
      _record_goods_name(goods_by_name, duplicate_name, goods)
    end
  end
  return goods_by_name, duplicate_name
end

local function _record_product_goods_id(rt, entry, goods_id)
  rt.goods_id_by_product_id[entry.product_id] = goods_id
  local mapped_product_id = rt.product_id_by_goods_id[goods_id]
  if mapped_product_id == nil then
    rt.product_id_by_goods_id[goods_id] = entry.product_id
  elseif mapped_product_id ~= entry.product_id then
    logger.warn(
      "market paid goods ambiguous goods_id:",
      "goods_id=" .. tostring(goods_id),
      "product_id=" .. tostring(entry.product_id),
      "mapped_product_id=" .. tostring(mapped_product_id)
    )
  end
end

local function _warn_duplicate_name_match(entry, market_name, duplicate_name)
  if duplicate_name[market_name] then
    logger.warn(
      "market paid goods duplicate name match:",
      "name=" .. tostring(market_name),
      "product_id=" .. tostring(entry.product_id)
    )
  end
end

local function _record_goods_mapping(rt, entry, market_name, goods_id, duplicate_name)
  _record_product_goods_id(rt, entry, goods_id)
  _warn_duplicate_name_match(entry, market_name, duplicate_name)
end

local function _resolve_missing_mapping_reason(goods_list)
  if type(goods_list) == "table" then
    return "name_mapping_not_found"
  end
  return "goods_list_unavailable"
end

local function _is_missing_goods_id(goods_id)
  return goods_id == nil or goods_id == ""
end

local function _entry_product_id(entry)
  return entry and entry.product_id or nil
end

local function _try_record_entry_mapping(rt, entry)
  local goods_list = _load_goods_list()
  local goods_by_name, duplicate_name = _index_goods_by_name(goods_list)
  local market_name = entry.name
  local goods = market_name and goods_by_name[market_name] or nil
  local goods_id = goods and goods.goods_id or nil
  if not _is_missing_goods_id(goods_id) then
    _record_goods_mapping(rt, entry, market_name, goods_id, duplicate_name)
    return goods_id, nil
  end
  return nil, _resolve_missing_mapping_reason(goods_list)
end

local function _lookup_goods_id(rt, entry, product_id)
  local goods_id = rt.goods_id_by_product_id[product_id]
  if _is_missing_goods_id(goods_id) then
    return _try_record_entry_mapping(rt, entry)
  end
  return goods_id, nil
end

local function _missing_goods_id_result(rt, entry, missing_reason, opts)
  if opts.warn_missing == true then
    _warn_mapping_missing_once(rt, entry, missing_reason)
  end
  return nil, "goods_mapping_missing"
end

local function _resolve_goods_id(game, entry, opts)
  opts = opts or {}
  local rt = _runtime(game)
  local product_id = _entry_product_id(entry)
  if product_id == nil then
    return nil, "missing_entry"
  end
  local goods_id, missing_reason = _lookup_goods_id(rt, entry, product_id)
  if _is_missing_goods_id(goods_id) then
    return _missing_goods_id_result(rt, entry, missing_reason, opts)
  end
  return goods_id, nil
end

local function _pending_queue(rt, role_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    queue = {}
    rt.pending_by_role_id[role_id] = queue
  end
  return queue
end

local function _push_pending(rt, role_id, pending)
  local queue = _pending_queue(rt, role_id)
  queue[#queue + 1] = pending
end

local function _consume_pending(rt, role_id, goods_id)
  local queue = rt.pending_by_role_id[role_id]
  if type(queue) ~= "table" then
    return nil
  end
  local target_goods_id = tostring(goods_id)
  for index, pending in ipairs(queue) do
    if tostring(pending.goods_id) == target_goods_id then
      table.remove(queue, index)
      if #queue == 0 then
        rt.pending_by_role_id[role_id] = nil
      end
      return pending
    end
  end
  return nil
end

local function _callback_goods_id(data)
  local goods_id = data and data.goods_id or nil
  if goods_id == nil or goods_id == "" then
    logger.warn("market paid callback ignored: goods_id missing")
    return nil
  end
  return goods_id
end

local function _callback_role_id(data)
  return _resolve_role_id(nil, data and data.role or nil)
end

local function _consume_callback_pending(rt, data, goods_id)
  local callback_role_id = _callback_role_id(data)
  local pending = callback_role_id and _consume_pending(rt, callback_role_id, goods_id) or nil
  if pending then
    return pending
  end
  logger.warn("market paid callback ignored: pending missing", "role_id=" .. tostring(callback_role_id), "goods_id=" .. tostring(goods_id))
  return nil
end

local function _callback_player(game, pending)
  local callback_player = game:find_player_by_id(pending.player_id)
  if callback_player then
    return callback_player
  end
  logger.warn("market paid callback ignored: player missing", "player_id=" .. tostring(pending.player_id))
  return nil
end

local function _callback_entry(pending)
  local entry = pending.entry
  if entry then
    return entry
  end
  logger.warn("market paid callback ignored: market entry missing", "product_id=" .. tostring(pending.product_id))
  return nil
end

local function _run_purchase_handler(game, rt, callback_player, entry, pending)
  if type(pending.on_purchase) == "function" then
    pending.on_purchase(game, callback_player, entry, pending)
    return
  end
  if type(rt.on_purchase) == "function" then
    rt.on_purchase(game, callback_player, entry, pending)
  end
end

local function _hide_purchase_panel(player)
  local panel_role = _resolve_role(player)
  if panel_role and type(panel_role.set_goods_panel_visible) == "function" then
    pcall(panel_role.set_goods_panel_visible, false)
  end
end

local function _on_purchase_goods_callback(game, rt, data)
  local goods_id = _callback_goods_id(data)
  if goods_id == nil then
    return
  end
  local pending = _consume_callback_pending(rt, data, goods_id)
  if pending == nil then
    return
  end
  local callback_player = _callback_player(game, pending)
  if callback_player == nil then
    return
  end
  local entry = _callback_entry(pending)
  if entry == nil then
    return
  end
  _run_purchase_handler(game, rt, callback_player, entry, pending)
  _hide_purchase_panel(callback_player)
end

local function _register_purchase_event_for_role(game, player)
  if not RegisterTriggerEvent or not EVENT or not EVENT.SPEC_ROLE_PURCHASE_GOODS then
    return
  end
  local role = _resolve_role(player)
  if not role then
    return
  end
  local role_id = _resolve_role_id(player, role)
  if role_id == nil then
    return
  end
  local rt = _runtime(game)
  if rt.registered_role_ids[role_id] then
    return
  end
  RegisterTriggerEvent({ EVENT.SPEC_ROLE_PURCHASE_GOODS, role_id }, function(_, _, data)
    _on_purchase_goods_callback(game, rt, data)
  end)
  rt.registered_role_ids[role_id] = true
end

local function _set_runtime_on_purchase(rt, on_purchase)
  if type(on_purchase) == "function" then
    rt.on_purchase = on_purchase
  end
end

local function _setup_purchase_events(game, rt)
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return
  end
  for _, player in ipairs(players) do
    _register_purchase_event_for_role(game, player)
  end
end

function gateway.setup_for_game(game, on_purchase)
  local rt = _runtime(game)
  _set_runtime_on_purchase(rt, on_purchase)
  if rt.setup_done == true then
    return
  end
  _setup_purchase_events(game, rt)
  rt.setup_done = true
end

function gateway.can_start(game, player, entry)
  gateway.setup_for_game(game)
  local goods_id, goods_reason = _resolve_goods_id(game, entry)
  if goods_id == nil then
    return false, goods_reason
  end
  local role = _resolve_role(player)
  if not role then
    return false, "role_unresolved"
  end
  if type(role.show_goods_purchase_panel) ~= "function" then
    return false, "purchase_api_missing"
  end
  return true, goods_id
end

local function _resolve_purchase_panel_role(player)
  local role = _resolve_role(player)
  if not role then
    return nil, "role_unresolved"
  end
  if type(role.show_goods_purchase_panel) ~= "function" then
    return nil, "purchase_api_missing"
  end
  return role, nil
end

local function _resolve_start_context(game, player, entry)
  gateway.setup_for_game(game)
  local goods_id, goods_reason = _resolve_goods_id(game, entry, { warn_missing = true })
  if goods_id == nil then
    return nil, goods_reason
  end
  local role, role_reason = _resolve_purchase_panel_role(player)
  if role == nil then
    return nil, role_reason
  end
  local role_id = _resolve_role_id(player, role)
  return {
    goods_id = goods_id,
    role = role,
    role_id = role_id,
  }, nil
end

local function _show_purchase_panel(player, entry, context)
  local ok_call = pcall(context.role.show_goods_purchase_panel, context.goods_id, panel_show_seconds)
  if not ok_call then
    logger.warn(
      "market paid panel call failed",
      "player_id=" .. tostring(player.id),
      "product_id=" .. tostring(entry.product_id),
      "goods_id=" .. tostring(context.goods_id)
    )
    return false
  end
  return true
end

function gateway.start(game, player, entry)
  local context, reason = _resolve_start_context(game, player, entry)
  if context == nil then
    return false, reason
  end
  if not _show_purchase_panel(player, entry, context) then
    return false, "panel_call_failed"
  end
  local rt = _runtime(game)
  _push_pending(rt, context.role_id, {
    player_id = player.id,
    product_id = entry.product_id,
    entry = entry,
    goods_id = context.goods_id,
    on_purchase = type(entry.on_purchase) == "function" and entry.on_purchase or nil,
  })
  return true, nil
end

-- Test seam exports
gateway._on_purchase_goods_callback = _on_purchase_goods_callback
gateway._runtime = _runtime
gateway._push_pending = _push_pending

return gateway

--[[ mutate4lua-manifest
version=2
projectHash=86456857294b6051
scope.0.id=chunk:src/host/paid_purchase_gateway.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=448
scope.0.semanticHash=b6f76b3b01186ead
scope.0.lastMutatedAt=2026-05-29T07:11:52Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=25
scope.0.lastMutationKilled=25
scope.1.id=function:_new_runtime:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=19
scope.1.semanticHash=87e3910f3bd56e09
scope.1.lastMutatedAt=2026-05-29T07:11:52Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_runtime:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=28
scope.2.semanticHash=206302e4dd3670a9
scope.2.lastMutatedAt=2026-05-29T07:11:52Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_resolve_role:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=39
scope.3.semanticHash=90894feee11c7516
scope.3.lastMutatedAt=2026-05-29T07:11:52Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:_resolve_role_id:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=50
scope.4.semanticHash=b769a4f0fc2248a5
scope.4.lastMutatedAt=2026-05-29T07:11:52Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=10
scope.4.lastMutationKilled=10
scope.5.id=function:_mapping_warning_already_seen:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=57
scope.5.semanticHash=dd72e87ce297a65a
scope.5.lastMutatedAt=2026-05-29T07:11:52Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_warn_mapping_missing_once:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=72
scope.6.semanticHash=d009ad42cd43664d
scope.6.lastMutatedAt=2026-05-29T07:11:52Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_load_goods_list:74
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=90
scope.7.semanticHash=8b0985d86b2090f1
scope.7.lastMutatedAt=2026-05-29T07:11:52Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=9
scope.7.lastMutationKilled=9
scope.8.id=function:_record_goods_name:92
scope.8.kind=function
scope.8.startLine=92
scope.8.endLine=105
scope.8.semanticHash=88470499a23edec5
scope.8.lastMutatedAt=2026-05-29T07:11:52Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=10
scope.8.lastMutationKilled=10
scope.9.id=function:_record_product_goods_id:118
scope.9.kind=function
scope.9.startLine=118
scope.9.endLine=131
scope.9.semanticHash=d831279f2587e32f
scope.9.lastMutatedAt=2026-05-29T07:11:52Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=3
scope.9.lastMutationKilled=3
scope.10.id=function:_warn_duplicate_name_match:133
scope.10.kind=function
scope.10.startLine=133
scope.10.endLine=141
scope.10.semanticHash=8be411ffd616a9ba
scope.10.lastMutatedAt=2026-05-29T07:11:52Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:_record_goods_mapping:143
scope.11.kind=function
scope.11.startLine=143
scope.11.endLine=146
scope.11.semanticHash=9ee70fd7c2c213f7
scope.11.lastMutatedAt=2026-05-29T07:11:52Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=2
scope.11.lastMutationKilled=2
scope.12.id=function:_resolve_missing_mapping_reason:148
scope.12.kind=function
scope.12.startLine=148
scope.12.endLine=153
scope.12.semanticHash=8c533104df9c76ae
scope.12.lastMutatedAt=2026-05-29T07:11:52Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=5
scope.12.lastMutationKilled=5
scope.13.id=function:_is_missing_goods_id:155
scope.13.kind=function
scope.13.startLine=155
scope.13.endLine=157
scope.13.semanticHash=56aef6506ab81d8e
scope.13.lastMutatedAt=2026-05-29T07:11:52Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=4
scope.13.lastMutationKilled=4
scope.14.id=function:_entry_product_id:159
scope.14.kind=function
scope.14.startLine=159
scope.14.endLine=161
scope.14.semanticHash=87a7b19974f2b4d8
scope.14.lastMutatedAt=2026-05-29T07:11:52Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=2
scope.14.lastMutationKilled=2
scope.15.id=function:_try_record_entry_mapping:163
scope.15.kind=function
scope.15.startLine=163
scope.15.endLine=174
scope.15.semanticHash=6ba45e15d647be88
scope.15.lastMutatedAt=2026-05-29T07:11:52Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=10
scope.15.lastMutationKilled=10
scope.16.id=function:_lookup_goods_id:176
scope.16.kind=function
scope.16.startLine=176
scope.16.endLine=182
scope.16.semanticHash=1e6bff42e8380786
scope.16.lastMutatedAt=2026-05-29T07:11:52Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=2
scope.16.lastMutationKilled=2
scope.17.id=function:_missing_goods_id_result:184
scope.17.kind=function
scope.17.startLine=184
scope.17.endLine=189
scope.17.semanticHash=62005f53f14e11c2
scope.17.lastMutatedAt=2026-05-29T07:11:52Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=4
scope.17.lastMutationKilled=4
scope.18.id=function:_resolve_goods_id:191
scope.18.kind=function
scope.18.startLine=191
scope.18.endLine=203
scope.18.semanticHash=cbc4dcc339ec48d4
scope.18.lastMutatedAt=2026-05-29T07:11:52Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=8
scope.18.lastMutationKilled=8
scope.19.id=function:_pending_queue:205
scope.19.kind=function
scope.19.startLine=205
scope.19.endLine=212
scope.19.semanticHash=e0b4f14f530d1ed7
scope.19.lastMutatedAt=2026-05-29T07:11:52Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=3
scope.19.lastMutationKilled=3
scope.20.id=function:_push_pending:214
scope.20.kind=function
scope.20.startLine=214
scope.20.endLine=217
scope.20.semanticHash=8f85382de35c4b74
scope.20.lastMutatedAt=2026-05-29T07:11:52Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=3
scope.20.lastMutationKilled=3
scope.21.id=function:_callback_goods_id:237
scope.21.kind=function
scope.21.startLine=237
scope.21.endLine=244
scope.21.semanticHash=30517136bcc38419
scope.21.lastMutatedAt=2026-05-29T07:11:52Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=7
scope.21.lastMutationKilled=7
scope.22.id=function:_callback_role_id:246
scope.22.kind=function
scope.22.startLine=246
scope.22.endLine=248
scope.22.semanticHash=909afed3b4440c27
scope.22.lastMutatedAt=2026-05-29T07:11:52Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:_consume_callback_pending:250
scope.23.kind=function
scope.23.startLine=250
scope.23.endLine=258
scope.23.semanticHash=c0e549e6c158d4a7
scope.23.lastMutatedAt=2026-05-29T07:11:52Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=5
scope.23.lastMutationKilled=5
scope.24.id=function:_callback_player:260
scope.24.kind=function
scope.24.startLine=260
scope.24.endLine=267
scope.24.semanticHash=2cf725f1c6e8d31d
scope.24.lastMutatedAt=2026-05-29T07:11:52Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=2
scope.24.lastMutationKilled=2
scope.25.id=function:_callback_entry:269
scope.25.kind=function
scope.25.startLine=269
scope.25.endLine=276
scope.25.semanticHash=c491d02cd0bb0aa1
scope.25.lastMutatedAt=2026-05-29T07:11:52Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=1
scope.25.lastMutationKilled=1
scope.26.id=function:_run_purchase_handler:278
scope.26.kind=function
scope.26.startLine=278
scope.26.endLine=286
scope.26.semanticHash=362a085fea3c8d46
scope.26.lastMutatedAt=2026-05-29T07:11:52Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=passed
scope.26.lastMutationSites=8
scope.26.lastMutationKilled=8
scope.27.id=function:_hide_purchase_panel:288
scope.27.kind=function
scope.27.startLine=288
scope.27.endLine=293
scope.27.semanticHash=cf11306c81615ea9
scope.27.lastMutatedAt=2026-05-29T07:11:52Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=6
scope.27.lastMutationKilled=6
scope.28.id=function:_on_purchase_goods_callback:295
scope.28.kind=function
scope.28.startLine=295
scope.28.endLine=314
scope.28.semanticHash=cb2b1b6d46e79a45
scope.28.lastMutatedAt=2026-05-29T07:11:52Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=10
scope.28.lastMutationKilled=10
scope.29.id=function:anonymous@332:332
scope.29.kind=function
scope.29.startLine=332
scope.29.endLine=334
scope.29.semanticHash=eace4f3ec1f38aab
scope.29.lastMutatedAt=2026-05-29T07:11:52Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=no_sites
scope.29.lastMutationSites=0
scope.29.lastMutationKilled=0
scope.30.id=function:_register_purchase_event_for_role:316
scope.30.kind=function
scope.30.startLine=316
scope.30.endLine=336
scope.30.semanticHash=3aad8d2570b6f965
scope.30.lastMutatedAt=2026-05-29T07:11:52Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=12
scope.30.lastMutationKilled=12
scope.31.id=function:_set_runtime_on_purchase:338
scope.31.kind=function
scope.31.startLine=338
scope.31.endLine=342
scope.31.semanticHash=449753c4e4744cb8
scope.31.lastMutatedAt=2026-05-29T07:11:52Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=3
scope.31.lastMutationKilled=3
scope.32.id=function:gateway.setup_for_game:354
scope.32.kind=function
scope.32.startLine=354
scope.32.endLine=362
scope.32.semanticHash=a90d7f5b906d53d5
scope.32.lastMutatedAt=2026-05-29T07:11:52Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=6
scope.32.lastMutationKilled=6
scope.33.id=function:gateway.can_start:364
scope.33.kind=function
scope.33.startLine=364
scope.33.endLine=378
scope.33.semanticHash=8396e1e55f5ffd5b
scope.33.lastMutatedAt=2026-05-29T07:11:52Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=14
scope.33.lastMutationKilled=14
scope.34.id=function:_resolve_purchase_panel_role:380
scope.34.kind=function
scope.34.startLine=380
scope.34.endLine=389
scope.34.semanticHash=7d8e5a6371306c79
scope.34.lastMutatedAt=2026-05-29T07:11:52Z
scope.34.lastMutationLane=behavior
scope.34.lastMutationStatus=passed
scope.34.lastMutationSites=7
scope.34.lastMutationKilled=7
scope.35.id=function:_resolve_start_context:391
scope.35.kind=function
scope.35.startLine=391
scope.35.endLine=407
scope.35.semanticHash=a345221f25b6a179
scope.35.lastMutatedAt=2026-05-29T07:11:52Z
scope.35.lastMutationLane=behavior
scope.35.lastMutationStatus=passed
scope.35.lastMutationSites=6
scope.35.lastMutationKilled=6
scope.36.id=function:_show_purchase_panel:409
scope.36.kind=function
scope.36.startLine=409
scope.36.endLine=421
scope.36.semanticHash=5c56509147868945
scope.36.lastMutatedAt=2026-05-29T07:11:52Z
scope.36.lastMutationLane=behavior
scope.36.lastMutationStatus=passed
scope.36.lastMutationSites=5
scope.36.lastMutationKilled=5
scope.37.id=function:gateway.start:423
scope.37.kind=function
scope.37.startLine=423
scope.37.endLine=440
scope.37.semanticHash=f7147abf574d8c0b
scope.37.lastMutatedAt=2026-05-29T07:11:52Z
scope.37.lastMutationLane=behavior
scope.37.lastMutationStatus=passed
scope.37.lastMutationSites=10
scope.37.lastMutationKilled=10
]]
