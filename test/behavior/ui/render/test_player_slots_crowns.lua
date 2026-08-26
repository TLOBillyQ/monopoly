-- Behavior specs for the crown rule in src/ui/render/widgets/player_slots.lua:
-- the crown marks the living player with the highest total assets, and it is
-- shared when several players tie at the top.

local lu = require("luaunit")

local base_nodes = require("src.ui.schema.base")
local panel_player_slots = require("src.ui.render.widgets.player_slots")

local function _assert_eq(a, b, msg)
  lu.assertIs(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _stub_ui()
  local ui = { visible = {} }
  ui.set_visible = function(self, name, value)
    self.visible[name] = value
  end
  return ui
end

-- Crown visibility per slot index, after rendering the given rows.
local function _crowns(player_rows)
  local ui = _stub_ui()
  panel_player_slots.refresh_player_crowns(ui, player_rows)
  local crowns = {}
  for i = 1, 4 do
    crowns[i] = ui.visible[string.format(base_nodes.player_crown, i)]
  end
  return crowns
end

local function _row(total_assets_value, extra)
  local row = { total_assets_value = total_assets_value }
  for key, value in pairs(extra or {}) do
    row[key] = value
  end
  return row
end

TestPlayerSlotsCrowns = {}

function TestPlayerSlotsCrowns:test_crowns_the_single_richest_player()
  local crowns = _crowns({ _row(100), _row(300), _row(200), _row(50) })
  _assert_eq(crowns[1], false, "slot 1 uncrowned")
  _assert_eq(crowns[2], true, "the richest player wears the crown")
  _assert_eq(crowns[3], false, "slot 3 uncrowned")
  _assert_eq(crowns[4], false, "slot 4 uncrowned")
end

function TestPlayerSlotsCrowns:test_crowns_every_player_tied_at_the_top()
  local crowns = _crowns({ _row(300), _row(300), _row(200), _row(10) })
  _assert_eq(crowns[1], true, "first tied leader crowned")
  _assert_eq(crowns[2], true, "second tied leader crowned")
  _assert_eq(crowns[3], false, "the runner-up stays uncrowned")
end

function TestPlayerSlotsCrowns:test_never_crowns_an_eliminated_player_even_the_richest_one()
  local crowns = _crowns({
    _row(900, { eliminated = true }),
    _row(300),
    _row(200),
    _row(50),
  })
  _assert_eq(crowns[1], false, "an eliminated player holds no crown")
  _assert_eq(crowns[2], true, "the richest living player is crowned instead")
end

function TestPlayerSlotsCrowns:test_ignores_an_eliminated_player_when_picking_the_top_total()
  -- The eliminated row must not raise the bar: the living leader keeps the crown
  -- even though a dead player is richer.
  local crowns = _crowns({
    _row(300),
    _row(900, { eliminated = true }),
    _row(300),
    _row(10),
  })
  _assert_eq(crowns[1], true, "living leader crowned despite a richer eliminated player")
  _assert_eq(crowns[3], true, "the tied living leader is crowned too")
end

function TestPlayerSlotsCrowns:test_crowns_nobody_when_every_row_is_missing()
  local crowns = _crowns({})
  for i = 1, 4 do
    _assert_eq(crowns[i], false, "slot " .. i .. " uncrowned with no rows")
  end
end

function TestPlayerSlotsCrowns:test_crowns_nobody_when_every_player_is_eliminated()
  local crowns = _crowns({
    _row(300, { eliminated = true }),
    _row(100, { eliminated = true }),
  })
  _assert_eq(crowns[1], false, "no crown among the eliminated")
  _assert_eq(crowns[2], false, "no crown among the eliminated")
end

function TestPlayerSlotsCrowns:test_skips_players_whose_total_assets_are_not_a_number()
  local crowns = _crowns({ _row("n/a"), _row(120), _row(nil) })
  _assert_eq(crowns[1], false, "an unreadable total cannot win the crown")
  _assert_eq(crowns[2], true, "the only readable total wins")
  _assert_eq(crowns[3], false, "a missing total cannot win the crown")
end

function TestPlayerSlotsCrowns:test_crowns_a_leader_whose_total_is_zero_when_nobody_has_more()
  local crowns = _crowns({ _row(0), _row(-50) })
  _assert_eq(crowns[1], true, "zero still leads a negative total")
  _assert_eq(crowns[2], false, "the poorer player is uncrowned")
end

function TestPlayerSlotsCrowns:test_tolerates_a_ui_that_cannot_set_visibility()
  local ok = pcall(panel_player_slots.refresh_player_crowns, {}, { _row(100) })
  _assert_eq(ok, true, "a ui without set_visible must not crash the refresh")
end

function TestPlayerSlotsCrowns:test_tolerates_a_nil_ui_without_indexing_it()
  -- 杀 L34 or->and:ui=nil 时变异体求值 type(nil.set_visible) 索引 nil 报错。
  local ok = pcall(panel_player_slots.refresh_player_crowns, nil, { _row(100) })
  _assert_eq(ok, true, "a nil ui must be tolerated without indexing")
end

function TestPlayerSlotsCrowns:test_tolerates_a_nil_ui_in_force_item_slots()
  -- 杀 L68 and->or:ui=nil 时变异体求值 ui.set_visible 索引 nil 报错。
  local ok = pcall(panel_player_slots.force_item_slots_visible_for_player, nil, { is_player_role = true })
  _assert_eq(ok, true, "a nil ui must be tolerated without indexing")
end

function TestPlayerSlotsCrowns:test_does_not_set_slots_for_a_nil_context()
  -- 杀 L72 and->or 的 nil 输入观测:ctx=nil 时变异体求值 ctx.is_player_role 索引 nil 报错。
  local ui = {
    item_slots = { "slot_a" },
    set_visible = function() end,
  }
  local ok = pcall(panel_player_slots.force_item_slots_visible_for_player, ui, nil)
  _assert_eq(ok, true, "a nil ctx must be tolerated without indexing")
end

function TestPlayerSlotsCrowns:test_skips_slot_visibility_for_non_player_context()
  -- 杀 L72 and->or 的另一观测:ctx 存在但非玩家时,变异体放宽守卫误走 set_visible。
  local set_calls = {}
  local ui = {
    item_slots = { "slot_a" },
    set_visible = function(_, name, value)
      set_calls[#set_calls + 1] = { name, value }
    end,
  }
  panel_player_slots.force_item_slots_visible_for_player(ui, { is_player_role = false })
  _assert_eq(#set_calls, 0, "non-player context must not reveal item slots")
end


return TestPlayerSlotsCrowns
