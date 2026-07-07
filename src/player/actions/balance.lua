-- 角色属性金币深模块：局内经济结算的唯一金币余额。
-- 余额由角色 Fixed 属性（coin_count）承载，业务语义是非负整数金币。
-- 校验 / 存储（Role 属性读写）/ 结算（含 transfer 原子回滚）全部内聚于此，
-- 对外只暴露 balance_ops 结算接口；一次写入路径上同一不变量只在入口校验一次。
local action_anim_port = require("src.foundation.ports.action_anim")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local number_utils = require("src.foundation.number")
local common = require("src.player.actions.state_common")

local balance_ops = {}

local _COIN_COUNT_ATTR_ID = "coin_count"

balance_ops.COIN_COUNT_ATTR_ID = _COIN_COUNT_ATTR_ID

-- 校验：金额 / 变化量必须是有限整数，余额必须非负 --------------------------

local function _player_label(player)
  if player == nil then
    return "玩家?"
  end
  local id = player.id
  local name = player.name
  if id ~= nil and name ~= nil and name ~= "" then
    return "玩家" .. tostring(id) .. "(" .. tostring(name) .. ")"
  end
  if id ~= nil then
    return "玩家" .. tostring(id)
  end
  if name ~= nil and name ~= "" then
    return tostring(name)
  end
  return "玩家?"
end

local function _coin_error(player, reason)
  return _player_label(player) .. " " .. _COIN_COUNT_ATTR_ID .. " " .. tostring(reason)
end

local function _fail(player, reason)
  error(_coin_error(player, reason))
end

local function _is_finite_numeric(value)
  if not number_utils.is_numeric(value) then
    return false
  end
  local ok, diff = pcall(function()
    return value - value
  end)
  return ok and diff == 0
end

local function _require_finite_integer(player, value, label)
  if not _is_finite_numeric(value) then
    _fail(player, label .. "必须是有限整数")
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil or as_int ~= value then
    _fail(player, label .. "必须是有限整数")
  end
  return as_int
end

local function _validate_coin_amount(player, value, label)
  local as_int = _require_finite_integer(player, value, label)
  if as_int < 0 then
    _fail(player, label .. "不能为负数")
  end
  return as_int
end

local function _validate_delta(player, value)
  return _require_finite_integer(player, value, "金币变化量")
end

-- 存储：解析角色并读写 coin_count 属性 -------------------------------------

local function _as_fixed_number(amount)
  return amount + 0.0
end

local function _new_memory_coin_role(initial)
  local attrs = {}
  if initial ~= nil then
    attrs[_COIN_COUNT_ATTR_ID] = initial
  end
  local role = {}
  function role.get_attr_raw_fixed(first, second)
    local attr_id = first == role and second or first
    return attrs[attr_id]
  end
  function role.set_attr_raw_fixed(first, second, third)
    local attr_id = first == role and second or first
    local value = first == role and third or second
    attrs[attr_id] = value
    return true
  end
  return role
end

balance_ops.new_memory_coin_role = _new_memory_coin_role

local function _role_method(role, method_name)
  local fn = role and role[method_name] or nil
  if type(fn) ~= "function" then
    return nil
  end
  return fn
end

local function _role_with_coin_methods(role)
  local getter = _role_method(role, "get_attr_raw_fixed")
  local setter = _role_method(role, "set_attr_raw_fixed")
  if getter ~= nil and setter ~= nil then
    return role, getter, setter
  end
  return nil, getter, setter
end

local function _runtime_role_for(player)
  if player and player.id ~= nil then
    return runtime_ports.resolve_role(player.id)
  end
  return nil
end

local function _resolve_coin_role(player)
  local runtime_role = _runtime_role_for(player)
  local role, getter, setter = _role_with_coin_methods(runtime_role)
  if role ~= nil then
    return role, getter, setter
  end

  local player_role = player and player._coin_role or nil
  role, getter, setter = _role_with_coin_methods(player_role)
  if role ~= nil then
    return role, getter, setter
  end

  if runtime_role == nil and player_role == nil then
    _fail(player, "缺少Role")
  end
  _fail(player, "缺少get_attr_raw_fixed或set_attr_raw_fixed")
end

local function _read_coin_raw(player)
  local _, getter = _resolve_coin_role(player)
  local ok, value = pcall(getter, _COIN_COUNT_ATTR_ID)
  if not ok then
    _fail(player, "读取失败: " .. tostring(value))
  end
  return value
end

local function _read_coin_count(player)
  local value = _read_coin_raw(player)
  if value == nil then
    _fail(player, "未初始化")
  end
  return _validate_coin_amount(player, value, "读取值")
end

-- 前置条件：amount 已通过入口校验（有限非负整数），此处只做存储写入。
local function _try_write_coin_count(player, amount)
  local _, _, setter = _resolve_coin_role(player)
  local ok, result = pcall(setter, _COIN_COUNT_ATTR_ID, _as_fixed_number(amount))
  if not ok then
    return false, tostring(result)
  end
  if result == false then
    return false, "set_attr_raw_fixed返回" .. tostring(result)
  end
  return true, amount
end

-- 结算：写入编排、金币动画与 transfer 原子回滚 -----------------------------

local function _mark_players(game)
  if game ~= nil then
    common.mark_players(game)
  end
end

local function _queue_cash_anim(game, player, delta, opts)
  if opts and opts.suppress_cash_receive_anim == true then
    return
  end
  if delta == 0 then
    return
  end
  action_anim_port.queue(game, {
    kind = "cash_receive",
    player_id = player.id,
    amount = delta,
  })
end

-- 前置条件同 _try_write_coin_count：amount 已校验。
local function _write_coin_count(game, player, amount)
  local ok, result = _try_write_coin_count(player, amount)
  if not ok then
    _fail(player, "写入失败: " .. tostring(result))
  end
  _mark_players(game)
  return result
end

local function _set_coin_count(game, player, amount)
  return _write_coin_count(game, player, _validate_coin_amount(player, amount, "写入值"))
end

-- 前置条件：delta 已通过 _validate_delta；结果为负时钳制到 0。
local function _apply_coin_delta(game, player, delta, opts)
  local current_cash = _read_coin_count(player)
  local next_cash = current_cash + delta
  if next_cash < 0 then
    next_cash = 0
  end
  local updated_cash = _write_coin_count(game, player, next_cash)
  _queue_cash_anim(game, player, updated_cash - current_cash, opts)
  return updated_cash
end

local function _write_receiver_or_rollback(payer, payer_before, receiver, receiver_after)
  local receiver_ok, receiver_err = _try_write_coin_count(receiver, receiver_after)
  if receiver_ok then
    return
  end
  local rollback_ok, rollback_err = _try_write_coin_count(payer, payer_before)
  if not rollback_ok then
    error(_coin_error(receiver, "写入失败: " .. tostring(receiver_err)
      .. "; 回滚结果=fatal: " .. tostring(rollback_err)))
  end
  error(_coin_error(receiver, "写入失败: " .. tostring(receiver_err) .. "; 回滚结果=成功"))
end

local function _transfer_amount(payer, requested, opts)
  if requested < 0 then
    _fail(payer, "支付金额不能为负数")
  end
  local payer_before = _read_coin_count(payer)
  if opts and opts.allow_partial == true and payer_before < requested then
    return payer_before, payer_before
  end
  return requested, payer_before
end

-- 公开接口 ------------------------------------------------------------------

function balance_ops.initialize_player_coins(player, amount)
  local current = _read_coin_raw(player)
  if current ~= nil then
    return _validate_coin_amount(player, current, "读取值")
  end
  return _set_coin_count(nil, player, amount)
end

function balance_ops.seed_player_coins(player, amount)
  return _set_coin_count(nil, player, amount)
end

function balance_ops.player_balance(self, player, currency)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return _read_coin_count(player)
  end
  error("unsupported currency: " .. tostring(key))
end

function balance_ops.add_player_cash(self, player, amount, opts)
  local delta = _validate_delta(player, amount)
  return _apply_coin_delta(self, player, delta, opts)
end

function balance_ops.set_player_cash(self, player, amount)
  return _set_coin_count(self, player, amount)
end

function balance_ops.deduct_player_cash(self, player, amount, opts)
  local cost = _validate_delta(player, amount)
  local new_balance = _read_coin_count(player) - cost
  if new_balance < 0 then
    _fail(player, "余额不足: " .. tostring(new_balance))
  end
  return _apply_coin_delta(self, player, -cost, opts)
end

function balance_ops.transfer_player_cash(self, payer, receiver, amount, opts)
  local requested = _validate_delta(payer, amount)
  local actual, payer_before = _transfer_amount(payer, requested, opts)
  local receiver_before = _read_coin_count(receiver)
  local payer_after = payer_before - actual
  if payer_after < 0 then
    _fail(payer, "余额不足: " .. tostring(payer_after))
  end
  local receiver_after = receiver_before + actual
  _validate_coin_amount(receiver, receiver_after, "写入值")

  local payer_ok, payer_err = _try_write_coin_count(payer, payer_after)
  if not payer_ok then
    _fail(payer, "写入失败: " .. tostring(payer_err))
  end

  _write_receiver_or_rollback(payer, payer_before, receiver, receiver_after)

  _mark_players(self)
  _queue_cash_anim(self, payer, -actual, opts)
  _queue_cash_anim(self, receiver, actual, opts)
  return payer_after, receiver_after, actual
end

function balance_ops.deduct_player_balance(self, player, currency, amount, opts)
  local key = common.normalize_currency(currency)
  if key == "金币" then
    return self:deduct_player_cash(player, amount, opts)
  end
  error("unsupported currency: " .. tostring(key))
end

return balance_ops

--[[ mutate4lua-manifest
version=2
projectHash=a2aafd534ea98a8b
scope.0.id=chunk:src/player/actions/balance.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=322
scope.0.semanticHash=cca0801343fe52d8
scope.0.lastMutatedAt=2026-07-07T09:59:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:_player_label:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=34
scope.1.semanticHash=694d2874da2083c1
scope.1.lastMutatedAt=2026-07-07T09:59:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=22
scope.1.lastMutationKilled=22
scope.2.id=function:_coin_error:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=38
scope.2.semanticHash=080b0dc53351b0b7
scope.2.lastMutatedAt=2026-07-07T09:59:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_fail:40
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=42
scope.3.semanticHash=00cbb07ee34ca349
scope.3.lastMutatedAt=2026-07-07T09:59:09Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:anonymous@48:48
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=50
scope.4.semanticHash=909770022d29387e
scope.5.id=function:_is_finite_numeric:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=52
scope.5.semanticHash=6a53b4abe2ef643e
scope.5.lastMutatedAt=2026-07-07T09:59:09Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=5
scope.6.id=function:_require_finite_integer:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=63
scope.6.semanticHash=63a15c55c77a74a1
scope.6.lastMutatedAt=2026-07-07T09:59:09Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=8
scope.7.id=function:_validate_coin_amount:65
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=71
scope.7.semanticHash=9b94b153769589a6
scope.7.lastMutatedAt=2026-07-07T09:59:09Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_validate_delta:73
scope.8.kind=function
scope.8.startLine=73
scope.8.endLine=75
scope.8.semanticHash=5078705721aef9b4
scope.8.lastMutatedAt=2026-07-07T09:59:09Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:_as_fixed_number:79
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=81
scope.9.semanticHash=4fba23edf25ee76e
scope.9.lastMutatedAt=2026-07-07T09:59:09Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=0
scope.10.id=function:role.get_attr_raw_fixed:89
scope.10.kind=function
scope.10.startLine=89
scope.10.endLine=92
scope.10.semanticHash=e03b4dcc43cd030f
scope.10.lastMutatedAt=2026-07-07T09:59:09Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=3
scope.10.lastMutationKilled=3
scope.11.id=function:role.set_attr_raw_fixed:93
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=98
scope.11.semanticHash=ccaa590bd6969b60
scope.11.lastMutatedAt=2026-07-07T09:59:09Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=7
scope.11.lastMutationKilled=7
scope.12.id=function:_new_memory_coin_role:83
scope.12.kind=function
scope.12.startLine=83
scope.12.endLine=100
scope.12.semanticHash=0faa962a99c45102
scope.12.lastMutatedAt=2026-07-07T09:59:09Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:_role_method:104
scope.13.kind=function
scope.13.startLine=104
scope.13.endLine=110
scope.13.semanticHash=dff565a64608c82b
scope.13.lastMutatedAt=2026-07-07T09:59:09Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=5
scope.13.lastMutationKilled=5
scope.14.id=function:_role_with_coin_methods:112
scope.14.kind=function
scope.14.startLine=112
scope.14.endLine=119
scope.14.semanticHash=5c4badb7b6881f9d
scope.14.lastMutatedAt=2026-07-07T09:59:09Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:_runtime_role_for:121
scope.15.kind=function
scope.15.startLine=121
scope.15.endLine=126
scope.15.semanticHash=95b9d5e139e598d9
scope.15.lastMutatedAt=2026-07-07T09:59:09Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=3
scope.15.lastMutationKilled=3
scope.16.id=function:_resolve_coin_role:128
scope.16.kind=function
scope.16.startLine=128
scope.16.endLine=145
scope.16.semanticHash=49965f6b87c326e8
scope.16.lastMutatedAt=2026-07-07T09:59:09Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=12
scope.16.lastMutationKilled=12
scope.17.id=function:_read_coin_raw:147
scope.17.kind=function
scope.17.startLine=147
scope.17.endLine=154
scope.17.semanticHash=13fcdbd45115f28c
scope.17.lastMutatedAt=2026-07-07T09:59:09Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=4
scope.17.lastMutationKilled=4
scope.18.id=function:_read_coin_count:156
scope.18.kind=function
scope.18.startLine=156
scope.18.endLine=162
scope.18.semanticHash=b9da02209ff650d2
scope.18.lastMutatedAt=2026-07-07T09:59:09Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=4
scope.18.lastMutationKilled=4
scope.19.id=function:_try_write_coin_count:165
scope.19.kind=function
scope.19.startLine=165
scope.19.endLine=175
scope.19.semanticHash=1d667dc5edbfad65
scope.19.lastMutatedAt=2026-07-07T09:59:09Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=11
scope.19.lastMutationKilled=11
scope.20.id=function:_mark_players:179
scope.20.kind=function
scope.20.startLine=179
scope.20.endLine=183
scope.20.semanticHash=6defbfa967d212ab
scope.20.lastMutatedAt=2026-07-07T09:59:09Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=2
scope.20.lastMutationKilled=2
scope.21.id=function:_queue_cash_anim:185
scope.21.kind=function
scope.21.startLine=185
scope.21.endLine=197
scope.21.semanticHash=a14b90869a4fb8a1
scope.21.lastMutatedAt=2026-07-07T09:59:09Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=6
scope.21.lastMutationKilled=6
scope.22.id=function:_write_coin_count:200
scope.22.kind=function
scope.22.startLine=200
scope.22.endLine=207
scope.22.semanticHash=ac7d940b042af833
scope.22.lastMutatedAt=2026-07-07T09:59:09Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=4
scope.22.lastMutationKilled=4
scope.23.id=function:_set_coin_count:209
scope.23.kind=function
scope.23.startLine=209
scope.23.endLine=211
scope.23.semanticHash=99aea42e6f9c0c2d
scope.23.lastMutatedAt=2026-07-07T09:59:09Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:_apply_coin_delta:214
scope.24.kind=function
scope.24.startLine=214
scope.24.endLine=223
scope.24.semanticHash=fdb2e1b6d6bba233
scope.24.lastMutatedAt=2026-07-07T09:59:09Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=survived
scope.24.lastMutationSites=7
scope.24.lastMutationKilled=5
scope.25.id=function:_write_receiver_or_rollback:225
scope.25.kind=function
scope.25.startLine=225
scope.25.endLine=236
scope.25.semanticHash=4049d57d0e6c122b
scope.25.lastMutatedAt=2026-07-07T09:59:09Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=5
scope.25.lastMutationKilled=5
scope.26.id=function:_transfer_amount:238
scope.26.kind=function
scope.26.startLine=238
scope.26.endLine=247
scope.26.semanticHash=50b2997275019d1d
scope.26.lastMutatedAt=2026-07-07T09:59:09Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=survived
scope.26.lastMutationSites=9
scope.26.lastMutationKilled=8
scope.27.id=function:balance_ops.initialize_player_coins:251
scope.27.kind=function
scope.27.startLine=251
scope.27.endLine=257
scope.27.semanticHash=2ad675ce4efac2c3
scope.27.lastMutatedAt=2026-07-07T09:59:09Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=4
scope.27.lastMutationKilled=4
scope.28.id=function:balance_ops.seed_player_coins:259
scope.28.kind=function
scope.28.startLine=259
scope.28.endLine=261
scope.28.semanticHash=b6d74b8b2a0b7d1f
scope.28.lastMutatedAt=2026-07-07T09:59:09Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=1
scope.28.lastMutationKilled=1
scope.29.id=function:balance_ops.player_balance:263
scope.29.kind=function
scope.29.startLine=263
scope.29.endLine=269
scope.29.semanticHash=a45f98e71fdbc5a2
scope.29.lastMutatedAt=2026-07-07T09:59:09Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=5
scope.29.lastMutationKilled=5
scope.30.id=function:balance_ops.add_player_cash:271
scope.30.kind=function
scope.30.startLine=271
scope.30.endLine=274
scope.30.semanticHash=18b53f5ea3051142
scope.30.lastMutatedAt=2026-07-07T09:59:09Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=2
scope.30.lastMutationKilled=2
scope.31.id=function:balance_ops.set_player_cash:276
scope.31.kind=function
scope.31.startLine=276
scope.31.endLine=278
scope.31.semanticHash=063b01a4893e854a
scope.31.lastMutatedAt=2026-07-07T09:59:09Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
scope.32.id=function:balance_ops.deduct_player_cash:280
scope.32.kind=function
scope.32.startLine=280
scope.32.endLine=287
scope.32.semanticHash=30d8be2c6e324006
scope.32.lastMutatedAt=2026-07-07T09:59:09Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=7
scope.32.lastMutationKilled=7
scope.33.id=function:balance_ops.transfer_player_cash:289
scope.33.kind=function
scope.33.startLine=289
scope.33.endLine=311
scope.33.semanticHash=677b0f7fcec25a4c
scope.33.lastMutatedAt=2026-07-07T09:59:09Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=16
scope.33.lastMutationKilled=16
scope.34.id=function:balance_ops.deduct_player_balance:313
scope.34.kind=function
scope.34.startLine=313
scope.34.endLine=319
scope.34.semanticHash=29add5e9e99db7ac
scope.34.lastMutatedAt=2026-07-07T09:59:09Z
scope.34.lastMutationLane=behavior
scope.34.lastMutationStatus=passed
scope.34.lastMutationSites=5
scope.34.lastMutationKilled=5
]]
