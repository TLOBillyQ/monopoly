local Game = require("src.state.game_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain game state coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("init skips anim_gate_port when already set", function()
    local custom_port = { wait_move_anim = true, wait_action_anim = true }
    local g = Game:new({})
    g.anim_gate_port = custom_port
    g:init({})
    _assert_eq(g.anim_gate_port, custom_port,
      "pre-set anim_gate_port should not be replaced by default")
  end)

  it("init skips popup_port when already valid", function()
    local push_fn = function() return true end
    local g = Game:new({})
    g.popup_port = { push_popup = push_fn }
    g:init({})
    _assert_eq(g.popup_port.push_popup, push_fn,
      "pre-set popup_port with valid push_popup should not be replaced")
  end)

  it("init skips tip_output_port when already valid", function()
    local enqueue_fn = function() return true end
    local g = Game:new({})
    g.tip_output_port = { enqueue = enqueue_fn }
    g:init({})
    _assert_eq(g.tip_output_port.enqueue, enqueue_fn,
      "pre-set tip_output_port with valid enqueue should not be replaced")
  end)

  it("init skips tile_feedback_port when already valid", function()
    local fn = function() return true end
    local g = Game:new({})
    g.tile_feedback_port = { on_tile_upgraded = fn }
    g:init({})
    _assert_eq(g.tile_feedback_port.on_tile_upgraded, fn,
      "pre-set tile_feedback_port should not be replaced")
  end)

  it("init skips board_visual_feedback_port when already valid", function()
    local fn = function() return true end
    local g = Game:new({})
    g.board_visual_feedback_port = { sync_many = fn }
    g:init({})
    _assert_eq(g.board_visual_feedback_port.sync_many, fn,
      "pre-set board_visual_feedback_port should not be replaced")
  end)

  it("init skips bankruptcy_feedback_port when already valid", function()
    local fn = function() return true end
    local g = Game:new({})
    g.bankruptcy_feedback_port = { on_tiles_cleared = fn }
    g:init({})
    _assert_eq(g.bankruptcy_feedback_port.on_tiles_cleared, fn,
      "pre-set bankruptcy_feedback_port should not be replaced")
  end)

  it("init reinstalls popup_port when push_popup not function", function()
    local g = Game:new({})
    g.popup_port = { push_popup = "not_a_function" }
    g:init({})
    _assert_eq(type(g.popup_port.push_popup), "function",
      "invalid push_popup should trigger re-install of default")
  end)

  it("init reinstalls tip_output_port when enqueue not function", function()
    local g = Game:new({})
    g.tip_output_port = { enqueue = 42 }
    g:init({})
    _assert_eq(type(g.tip_output_port.enqueue), "function",
      "invalid enqueue should trigger re-install of default")
  end)

  it("ensure_popup_port errors when port invalid", function()
    local g = Game:new({})
    g.popup_port = nil
    local ok, err = pcall(function() g:ensure_popup_port() end)
    _assert_eq(ok, false, "ensure_popup_port should error when port is nil")
    assert(tostring(err):find("popup_port", 1, true),
      "error should mention popup_port: " .. tostring(err))
  end)

  it("ensure_tip_output_port errors when port invalid", function()
    local g = Game:new({})
    g.tip_output_port = nil
    local ok = pcall(function() g:ensure_tip_output_port() end)
    _assert_eq(ok, false, "ensure_tip_output_port should error when port is nil")
  end)

  it("ensure_tile_feedback_port errors when port invalid", function()
    local g = Game:new({})
    g.tile_feedback_port = nil
    local ok = pcall(function() g:ensure_tile_feedback_port() end)
    _assert_eq(ok, false, "ensure_tile_feedback_port should error when port is nil")
  end)

  it("ensure_board_visual_feedback_port errors when port invalid", function()
    local g = Game:new({})
    g.board_visual_feedback_port = nil
    local ok = pcall(function() g:ensure_board_visual_feedback_port() end)
    _assert_eq(ok, false, "ensure_board_visual_feedback_port should error when port is nil")
  end)

  it("ensure_popup_port returns port when valid", function()
    local g = Game:new({})
    local port = g:ensure_popup_port()
    assert(type(port) == "table" and type(port.push_popup) == "function",
      "ensure_popup_port should return valid port table")
  end)

  it("advance_turn returns early when finished", function()
    local g = Game:new({})
    g.finished = true
    local called = false
    g.turn_engine = { run_turn = function() called = true end }
    g:advance_turn()
    _assert_eq(called, false, "advance_turn should return early when finished=true")
  end)

  it("dispatch_action returns early when finished", function()
    local g = Game:new({})
    g.finished = true
    local called = false
    g.turn_engine = { dispatch = function() called = true end }
    g:dispatch_action({ type = "test" })
    _assert_eq(called, false, "dispatch_action should return early when finished=true")
  end)

  it("mark_players_dirty sets dirty flags", function()
    local g = Game:new({})
    g.dirty = { any = false, players = false }
    g:mark_players_dirty()
    _assert_eq(g.dirty.any, true, "mark_players_dirty should set dirty.any")
    _assert_eq(g.dirty.players, true, "mark_players_dirty should set dirty.players")
  end)

  it("mark_board_dirty sets dirty flags", function()
    local g = Game:new({})
    g.dirty = { any = false, board_tiles = false }
    g:mark_board_dirty()
    _assert_eq(g.dirty.any, true, "mark_board_dirty should set dirty.any")
    _assert_eq(g.dirty.board_tiles, true, "mark_board_dirty should set dirty.board_tiles")
  end)
end)
