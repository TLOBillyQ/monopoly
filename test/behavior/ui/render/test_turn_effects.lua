-- Behavior specs for src/ui/render/widgets/turn_effects.lua.
-- turn_effects.sync drives three per-role visuals off the ui model: the current
-- player's action highlight, the local "it's your turn" prompt, and the
-- "someone else is acting" prompt shown to everyone else.

local lu = require("luaunit")

local base_nodes = require("src.ui.schema.base")
local turn_effects = require("src.ui.render.widgets.turn_effects")

local function _assert_eq(a, b, msg)
  lu.assertIs(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- A runtime whose nodes are plain tables, so the specs can read back the
-- visible/text/disabled fields turn_effects wrote. Roles are driven through
-- for_each_role_or_global exactly as the real runtime does.
local function _fake_runtime(role_ids)
  local nodes = {}
  local roles = {}
  for _, id in ipairs(role_ids or {}) do
    roles[#roles + 1] = { id = id }
  end

  local runtime = {
    nodes = nodes,
    client_roles = {},
    query_node = function(name)
      nodes[name] = nodes[name] or {}
      return nodes[name]
    end,
    resolve_role_id = function(role)
      return role and role.id or nil
    end,
    for_each_role_or_global = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end,
  }
  runtime.set_client_role = function(role)
    runtime.client_roles[#runtime.client_roles + 1] = role and role.id or "nil"
  end
  return runtime
end

local function _sync(runtime, ui_model)
  turn_effects.sync({}, ui_model, { runtime = runtime })
end

local function _highlight_flags(runtime)
  local flags = {}
  for i, name in ipairs(base_nodes.player_action_effects) do
    local node = runtime.nodes[name]
    flags[i] = node and node.visible
  end
  return flags
end

local function _model(current_player_id, player_ids, phase, current_player_name)
  local players = {}
  for _, id in ipairs(player_ids or {}) do
    players[#players + 1] = { id = id }
  end
  return {
    current_player_id = current_player_id,
    current_player_name = current_player_name,
    board = { players = players, phase = phase },
  }
end

TestTurnEffects = {}

-- turn_effects current player highlight
function TestTurnEffects:test_shows_the_highlight_only_on_the_current_players_slot()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(2, { 1, 2, 3, 4 }, "wait_action"))

  local flags = _highlight_flags(runtime)
  _assert_eq(flags[1], false, "slot 1 not highlighted")
  _assert_eq(flags[2], true, "slot 2 is the current player")
  _assert_eq(flags[3], false, "slot 3 not highlighted")
  _assert_eq(flags[4], false, "slot 4 not highlighted")
end

function TestTurnEffects:test_matches_the_current_player_by_normalized_id_not_raw_equality()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model("2", { 1, 2 }, "wait_action"))
  _assert_eq(_highlight_flags(runtime)[2], true, "string id matches the numeric player id")
end

function TestTurnEffects:test_highlights_nobody_when_the_current_player_is_not_on_the_board()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(9, { 1, 2 }, "wait_action"))

  local flags = _highlight_flags(runtime)
  _assert_eq(flags[1], false, "slot 1 dark")
  _assert_eq(flags[2], false, "slot 2 dark")
end

function TestTurnEffects:test_highlights_nobody_when_there_is_no_current_player_id()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(nil, { 1, 2 }, "wait_action"))
  _assert_eq(_highlight_flags(runtime)[1], false, "no current player means no highlight")
end

function TestTurnEffects:test_highlights_nobody_when_the_model_carries_no_board()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, { current_player_id = 1 })
  _assert_eq(_highlight_flags(runtime)[1], false, "a boardless model highlights nothing")
end

-- turn_effects local turn prompt
function TestTurnEffects:test_shows_the_prompt_to_the_player_whose_turn_it_is_during_wait_action()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action"))

  local star = runtime.nodes[base_nodes.action_hint_effect]
  local label = runtime.nodes[base_nodes.action_hint]
  _assert_eq(star.visible, true, "hint effect shown to the acting player")
  _assert_eq(label.visible, true, "hint label shown to the acting player")
  _assert_eq(star.disabled, true, "hint effect is non-interactive")
  _assert_eq(label.disabled, true, "hint label is non-interactive")
end

function TestTurnEffects:test_hides_the_prompt_from_a_player_whose_turn_it_is_not()
  local runtime = _fake_runtime({ 2 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action"))
  _assert_eq(runtime.nodes[base_nodes.action_hint].visible, false, "non-acting player sees no prompt")
end

function TestTurnEffects:test_hides_the_prompt_outside_the_wait_action_phase()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(1, { 1, 2 }, "moving"))
  _assert_eq(runtime.nodes[base_nodes.action_hint].visible, false,
    "the prompt belongs to wait_action only")
end

function TestTurnEffects:test_hides_the_prompt_when_the_role_has_no_id()
  local runtime = _fake_runtime({ 1 })
  runtime.resolve_role_id = function() return nil end
  _sync(runtime, _model(1, { 1, 2 }, "wait_action"))
  _assert_eq(runtime.nodes[base_nodes.action_hint].visible, false, "an unidentified role gets no prompt")
end

-- turn_effects other player action prompt
function TestTurnEffects:test_tells_a_waiting_player_who_is_acting_by_name()
  local runtime = _fake_runtime({ 2 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action", "阿呆"))

  local hint = runtime.nodes[base_nodes.other_player_hint]
  _assert_eq(hint.text, "阿呆正在行动", "the acting player's name is in the prompt")
  _assert_eq(hint.visible, true, "the prompt is shown to the waiting player")
end

function TestTurnEffects:test_falls_back_to_a_generic_prompt_when_the_acting_player_has_no_name()
  local runtime = _fake_runtime({ 2 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action"))
  _assert_eq(runtime.nodes[base_nodes.other_player_hint].text, "其他玩家正在行动",
    "a nameless acting player yields the generic prompt")
end

function TestTurnEffects:test_falls_back_to_the_generic_prompt_for_an_empty_name()
  local runtime = _fake_runtime({ 2 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action", ""))
  _assert_eq(runtime.nodes[base_nodes.other_player_hint].text, "其他玩家正在行动",
    "an empty name yields the generic prompt")
end

function TestTurnEffects:test_re_renders_the_prompt_text_when_the_acting_player_changes()
  local runtime = _fake_runtime({ 3 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action", "阿呆"))
  _assert_eq(runtime.nodes[base_nodes.other_player_hint].text, "阿呆正在行动", "first name rendered")

  _sync(runtime, _model(2, { 1, 2 }, "wait_action", "阿瓜"))
  _assert_eq(runtime.nodes[base_nodes.other_player_hint].text, "阿瓜正在行动",
    "the cached prompt text follows the new acting player")
end

function TestTurnEffects:test_clears_the_prompt_for_the_player_who_is_acting()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(1, { 1, 2 }, "wait_action", "阿呆"))

  local hint = runtime.nodes[base_nodes.other_player_hint]
  _assert_eq(hint.text, "", "the acting player is not told someone else is acting")
  _assert_eq(hint.visible, false, "the prompt is hidden from the acting player")
end

function TestTurnEffects:test_clears_the_prompt_when_nobody_is_acting()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(nil, { 1, 2 }, "wait_action", "阿呆"))
  _assert_eq(runtime.nodes[base_nodes.other_player_hint].visible, false,
    "no acting player means no prompt")
end

-- turn_effects.sync runtime plumbing
function TestTurnEffects:test_prefers_deps_runtime_over_the_states_presentation_runtime()
  local deps_runtime = _fake_runtime({ 1 })
  local state_runtime = _fake_runtime({ 1 })
  turn_effects.sync(
    { presentation_runtime = { runtime = state_runtime } },
    _model(1, { 1 }, "wait_action"),
    { runtime = deps_runtime }
  )
  _assert_eq(_highlight_flags(deps_runtime)[1], true, "deps.runtime is the one written to")
  _assert_eq(state_runtime.nodes[base_nodes.action_hint], nil, "the state runtime is untouched")
end

function TestTurnEffects:test_falls_back_to_the_states_presentation_runtime_when_deps_carries_none()
  local state_runtime = _fake_runtime({ 1 })
  turn_effects.sync(
    { presentation_runtime = { runtime = state_runtime } },
    _model(1, { 1 }, "wait_action"),
    nil
  )
  _assert_eq(_highlight_flags(state_runtime)[1], true, "the presentation runtime is used")
end

function TestTurnEffects:test_releases_the_client_role_when_the_sync_finishes()
  local runtime = _fake_runtime({ 1 })
  _sync(runtime, _model(1, { 1 }, "wait_action"))
  local roles = runtime.client_roles
  _assert_eq(roles[#roles], "nil", "the client role is cleared after the last per-role pass")
end


return TestTurnEffects
