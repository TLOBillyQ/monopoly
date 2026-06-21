local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local achievement = require("src.app.host_integrations.achievement")
local achievement_runtime = require("src.app.host_integrations.achievement_runtime")
local achievement_progress_port = require("src.rules.ports.achievement_progress")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _make_progress_role(calls)
  return {
    add_achievement_progress = function(id, amount)
      calls[#calls + 1] = { id = id, amount = amount }
      return true
    end,
  }
end

local function _clear(list)
  for index = #list, 1, -1 do
    list[index] = nil
  end
end

local function _assert_progress_calls(calls, expected_ids, expected_amount, label)
  _assert_eq(#calls, #expected_ids, label .. " call count")
  for index, id in ipairs(expected_ids) do
    _assert_eq(calls[index].id, id, label .. " id " .. tostring(index))
    _assert_eq(calls[index].amount, expected_amount, label .. " amount " .. tostring(index))
  end
end

describe("achievement catalog", function()
  after_each(function()
    achievement.reset_for_tests()
    achievement_progress_port.reset_for_tests()
    runtime_ports.reset_for_tests()
  end)

  it("exposes the full editor achievement catalog", function()
    _assert_eq(achievement.count(), 45, "achievement count")
    _assert_eq(achievement.ids_are_contiguous(1, 45), true, "achievement ids should be contiguous")

    local counts = achievement.category_counts()
    _assert_eq(counts["简单"], 11, "simple achievement count")
    _assert_eq(counts["普通"], 6, "normal achievement count")
    _assert_eq(counts["困难"], 8, "hard achievement count")
    _assert_eq(counts["传奇"], 12, "legend achievement count")
    _assert_eq(counts["隐藏"], 8, "hidden achievement count")
  end)

  it("finds achievements by editor id", function()
    local first = achievement.find(1)
    assert(first ~= nil, "achievement 1 should exist")
    _assert_eq(first.name, "最强大富翁I", "achievement 1 name")
    _assert_eq(first.category, "简单", "achievement 1 category")
    _assert_eq(first.condition, "获得1场游戏的胜利", "achievement 1 condition")
    _assert_eq(first.target_progress, 1, "achievement 1 target progress")

    local hidden = achievement.find("40")
    assert(hidden ~= nil, "achievement 40 should exist")
    _assert_eq(hidden.name, "小猪佩奇！", "achievement 40 name")
    _assert_eq(hidden.category, "传奇", "achievement 40 category")
    _assert_eq(hidden.condition, "使用小猪佩奇皮肤1次", "achievement 40 condition")
    _assert_eq(hidden.target_progress, 1, "achievement 40 target progress")

    _assert_eq(achievement.find(0), nil, "unknown achievement should not resolve")
  end)

  it("routes direct progress additions to the configured host adapter", function()
    local calls = {}
    local progress = {}
    achievement.configure_progress_adapter({
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        progress[id] = (progress[id] or 0) + amount
        return true
      end,
      get_achievement_progress = function(id)
        return progress[id] or 0
      end,
    })

    _assert_eq(achievement.host_pending, false, "achievement integration should be connected")
    _assert_eq(achievement.add_progress(1, 2), true, "known achievement should route to host")
    _assert_eq(calls[1].id, 1, "host adapter should receive achievement id")
    _assert_eq(calls[1].amount, 2, "host adapter should receive progress delta")
    _assert_eq(achievement.current_progress(1), 2, "progress reads should come from host adapter")
  end)

  it("routes progress through the first resolved runtime role when no test adapter is configured", function()
    local calls = {}
    local progress = {}
    local role = {
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        progress[id] = (progress[id] or 0) + amount
        return true
      end,
      get_achievement_progress = function(id)
        return progress[id] or 0
      end,
      snapshot = function()
        return progress
      end,
    }
    runtime_ports.configure({
      resolve_roles = function()
        return { role }
      end,
    })

    _assert_eq(achievement.add_progress(1, 3), true, "runtime role should receive progress")
    _assert_eq(calls[1].id, 1, "runtime role should receive achievement id")
    _assert_eq(calls[1].amount, 3, "runtime role should receive amount")
    _assert_eq(achievement.current_progress(1), 3, "runtime role should serve progress reads")
    _assert_eq(achievement.snapshot(), progress, "runtime role should serve snapshots")
  end)

  it("rejects invalid progress args before calling the host adapter", function()
    local calls = 0
    achievement.configure_progress_adapter({
      add_achievement_progress = function()
        calls = calls + 1
        return true
      end,
    })

    _assert_eq(achievement.add_progress(1, "not-a-number"), false, "invalid amount should be rejected")
    _assert_eq(achievement.add_progress(999, 1), false, "unknown achievement should be rejected")
    _assert_eq(calls, 0, "invalid progress should not call host")
  end)

  it("treats explicit host progress refusal as failure", function()
    achievement.configure_progress_adapter({
      add_achievement_progress = function()
        return false
      end,
    })

    _assert_eq(achievement.add_progress(1, 1), false, "host refusal should fail progress routing")
  end)

  it("rejects malformed contiguous-id ranges without throwing", function()
    _assert_eq(achievement.ids_are_contiguous(nil, 45), false, "missing start id should be rejected")
    _assert_eq(achievement.ids_are_contiguous(1, nil), false, "missing end id should be rejected")
    _assert_eq(achievement.ids_are_contiguous(45, 1), false, "reversed id range should be rejected")
  end)

  it("fans cumulative gameplay events out to every mapped achievement", function()
    local calls = {}
    local progress = {}
    achievement.configure_progress_adapter({
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        progress[id] = (progress[id] or 1000) + amount
        return true
      end,
      get_achievement_progress = function(id)
        return progress[id] or 0
      end,
    })

    _assert_eq(achievement.record_gameplay_event("收取金币", 500), true, "mapped event should advance achievements")
    _assert_eq(#calls, 4, "cash collection should update four achievement ids")
    for index, id in ipairs({ 9, 10, 11, 12 }) do
      _assert_eq(calls[index].id, id, "cash collection achievement id " .. tostring(index))
      _assert_eq(calls[index].amount, 500, "cash collection progress delta")
      _assert_eq(achievement.current_progress(id), 1500, "cash collection current progress")
    end
  end)

  it("advances single mapped gameplay events by one point", function()
    local calls = {}
    achievement.configure_progress_adapter({
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        return true
      end,
    })

    _assert_eq(achievement.record_gameplay_event("使用小猪佩奇皮肤"), true, "skin event should advance achievement")
    _assert_eq(#calls, 1, "skin event should update one achievement")
    _assert_eq(calls[1].id, 40, "skin event achievement id")
    _assert_eq(calls[1].amount, 1, "single event progress delta")
  end)

  it("does not advance unmapped or failed gameplay events", function()
    local calls = {}
    achievement.configure_progress_adapter({
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        return true
      end,
    })

    _assert_eq(achievement.record_gameplay_event("未映射事件"), false, "unknown event should be ignored")
    _assert_eq(achievement.record_gameplay_event("黑市购买失败"), false, "failed purchase should be ignored")
    _assert_eq(achievement.record_gameplay_event("皮肤装备失败"), false, "failed skin equip should be ignored")
    _assert_eq(#calls, 0, "ignored events should not call host adapter")
  end)

  it("reports mapped gameplay events as unadvanced when every host call fails", function()
    local calls = 0
    achievement.configure_progress_adapter({
      add_achievement_progress = function()
        calls = calls + 1
        return false
      end,
    })

    _assert_eq(achievement.record_gameplay_event("游戏胜利"), false, "all-failed event should not advance")
    _assert_eq(calls, 4, "mapped event should attempt every achievement id")
  end)

  it("returns adapter snapshots only when the host provides a table snapshot", function()
    local progress = { [1] = 7 }
    achievement.configure_progress_adapter({
      snapshot = function()
        return progress
      end,
    })
    _assert_eq(achievement.snapshot(), progress, "table snapshot should be returned")

    achievement.configure_progress_adapter({})
    _assert_eq(next(achievement.snapshot()), nil, "missing snapshot method should return empty snapshot")

    achievement.configure_progress_adapter({
      snapshot = function()
        return false
      end,
    })
    _assert_eq(next(achievement.snapshot()), nil, "non-table snapshot should return empty snapshot")
  end)

  it("rejects progress when no host adapter is available", function()
    _assert_eq(achievement.add_progress(1, 1), false, "Lua should not fake achievement progress")
    _assert_eq(next(achievement.snapshot()), nil, "achievement snapshot should stay empty")
  end)

  it("routes runtime gameplay events to the matching host role", function()
    local calls = {}
    local role = {
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        return true
      end,
    }
    runtime_ports.configure({
      resolve_role = function(player_id)
        if player_id == 2 then
          return role
        end
        return nil
      end,
    })
    achievement_progress_port.configure(achievement_runtime.build_port())

    _assert_eq(achievement_progress_port.cash_received(nil, { id = 2 }, 500), true,
      "runtime cash event should advance the matched role")
    _assert_eq(#calls, 4, "cash event should fan out to four achievements")
    _assert_eq(calls[1].id, 9, "cash achievement id")
    _assert_eq(calls[1].amount, 500, "cash achievement amount")
  end)

  it("maps every runtime achievement fact to the configured gameplay event", function()
    local calls = {}
    local role = _make_progress_role(calls)
    local player = { id = 7 }
    local port = achievement_runtime.build_port()
    runtime_ports.configure({
      resolve_role = function(player_id)
        if player_id == player.id then
          return role
        end
        return nil
      end,
    })

    local cases = {
      {
        label = "game win",
        expected_ids = { 1, 2, 3, 4 },
        expected_amount = 1,
        run = function() return port.game_won(nil, player) end,
      },
      {
        label = "land purchase",
        expected_ids = { 5, 6, 7, 8 },
        expected_amount = 1,
        run = function() return port.land_purchased(nil, player) end,
      },
      {
        label = "cash received",
        expected_ids = { 9, 10, 11, 12 },
        expected_amount = 1,
        run = function() return port.cash_received(nil, player, 1) end,
      },
      {
        label = "tax paid",
        expected_ids = { 13, 14, 15, 16 },
        expected_amount = 2500,
        run = function() return port.tax_paid(nil, player, 2500) end,
      },
      {
        label = "item used",
        expected_ids = { 17, 18, 19, 20 },
        expected_amount = 1,
        run = function() return port.item_used(nil, player) end,
      },
      {
        label = "chance card",
        expected_ids = { 21, 22, 23, 24 },
        expected_amount = 1,
        run = function() return port.chance_card_drawn(nil, player) end,
      },
      {
        label = "market item bought",
        expected_ids = { 25, 26, 27, 28 },
        expected_amount = 1,
        run = function() return port.market_item_bought(nil, player) end,
      },
      {
        label = "level one upgrade",
        expected_ids = { 29 },
        expected_amount = 1,
        run = function() return port.building_upgraded(nil, player, 1) end,
      },
      {
        label = "level two upgrade",
        expected_ids = { 30 },
        expected_amount = 1,
        run = function() return port.building_upgraded(nil, player, 2) end,
      },
      {
        label = "level three upgrade",
        expected_ids = { 31 },
        expected_amount = 1,
        run = function() return port.building_upgraded(nil, player, 3) end,
      },
      {
        label = "angel attached",
        expected_ids = { 32 },
        expected_amount = 1,
        run = function() return port.deity_attached(nil, player, "angel") end,
      },
      {
        label = "rich attached",
        expected_ids = { 33 },
        expected_amount = 1,
        run = function() return port.deity_attached(nil, player, "rich") end,
      },
      {
        label = "poor attached",
        expected_ids = { 34 },
        expected_amount = 1,
        run = function() return port.deity_attached(nil, player, "poor") end,
      },
      {
        label = "hospital",
        expected_ids = { 35 },
        expected_amount = 1,
        run = function() return port.location_effect(nil, player, "hospital") end,
      },
      {
        label = "mountain",
        expected_ids = { 36 },
        expected_amount = 1,
        run = function() return port.location_effect(nil, player, "mountain") end,
      },
      {
        label = "contiguous lands",
        expected_ids = { 37 },
        expected_amount = 1,
        run = function() return port.contiguous_lands(nil, player) end,
      },
      {
        label = "monster demolish",
        expected_ids = { 38 },
        expected_amount = 1,
        run = function() return port.monster_demolished_building(nil, player) end,
      },
      {
        label = "typhoon demolish",
        expected_ids = { 39 },
        expected_amount = 1,
        run = function() return port.typhoon_demolished_building(nil, player) end,
      },
    }

    for _, case in ipairs(cases) do
      _clear(calls)
      _assert_eq(case.run(), true, case.label .. " should advance achievement progress")
      _assert_progress_calls(calls, case.expected_ids, case.expected_amount, case.label)
    end
  end)

  it("records direct runtime events through host-capable role subjects", function()
    local calls = {}
    local role = _make_progress_role(calls)

    _assert_eq(achievement_runtime.record_event(role, "游戏胜利"), true,
      "direct host role subject should receive runtime achievement progress")
    _assert_progress_calls(calls, { 1, 2, 3, 4 }, 1, "direct role game win")
  end)

  it("rejects runtime facts with invalid amounts or unknown event variants", function()
    local calls = {}
    local role = _make_progress_role(calls)
    local player = { id = 7 }
    local port = achievement_runtime.build_port()
    runtime_ports.configure({
      resolve_role = function(player_id)
        if player_id == player.id then
          return role
        end
        return nil
      end,
    })

    _assert_eq(port.cash_received(nil, player, 0), false, "zero cash should not advance")
    _assert_eq(port.cash_received(nil, player, nil), false, "missing cash amount should not advance")
    _assert_eq(port.tax_paid(nil, player, -1), false, "negative tax should not advance")
    _assert_eq(port.building_upgraded(nil, player, 4), false, "unknown building level should not advance")
    _assert_eq(port.deity_attached(nil, player, "unknown"), false, "unknown deity should not advance")
    _assert_eq(port.location_effect(nil, player, "unknown"), false, "unknown location effect should not advance")
    _assert_eq(achievement_runtime.record_event(player, nil), false, "missing runtime event should not advance")
    _assert_eq(#calls, 0, "invalid runtime facts should not call the role")
  end)

  it("rejects malformed runtime skin equip facts before resolving a role", function()
    local calls = {}
    local resolve_calls = 0
    local role = _make_progress_role(calls)
    local port = achievement_runtime.build_port()
    runtime_ports.configure({
      resolve_role = function()
        resolve_calls = resolve_calls + 1
        return role
      end,
    })

    _assert_eq(port.skin_equipped(nil, 7, nil), false, "missing skin should be rejected")
    _assert_eq(port.skin_equipped(nil, 7, {}), false, "skin without a name should be rejected")
    _assert_eq(port.skin_equipped(nil, 7, { name = "" }), false, "blank skin name should be rejected")
    _assert_eq(resolve_calls, 0, "malformed skin facts should not resolve a role")
    _assert_eq(#calls, 0, "malformed skin facts should not call the role")
  end)

  it("does not fall back to another role for player-specific runtime events", function()
    local calls = 0
    runtime_ports.configure({
      resolve_roles = function()
        return {
          {
            add_achievement_progress = function()
              calls = calls + 1
              return true
            end,
          },
        }
      end,
      resolve_role = function()
        return nil
      end,
    })
    achievement_progress_port.configure(achievement_runtime.build_port())

    _assert_eq(achievement_progress_port.item_used(nil, { id = 99 }), false,
      "unresolved player event should not advance another role")
    _assert_eq(calls, 0, "fallback role should not receive player-specific progress")
  end)

  it("maps runtime skin equips by configured skin name", function()
    local calls = {}
    local role = {
      add_achievement_progress = function(id, amount)
        calls[#calls + 1] = { id = id, amount = amount }
        return true
      end,
    }
    runtime_ports.configure({
      resolve_role = function(player_id)
        if player_id == 7 then return role end
        return nil
      end,
    })
    achievement_progress_port.configure(achievement_runtime.build_port())

    _assert_eq(achievement_progress_port.skin_equipped(nil, 7, { name = "小猪佩奇" }), true,
      "skin equip should map by skin name")
    _assert_eq(#calls, 1, "skin equip should update one achievement")
    _assert_eq(calls[1].id, 40, "peppa skin achievement id")
    _assert_eq(calls[1].amount, 1, "skin equip amount")
  end)
end)
