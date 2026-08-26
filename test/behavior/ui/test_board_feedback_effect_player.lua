-- board_feedback/effect_player 直驱规约(#262 幸存闭合):with_sound 的
-- payload 优先、rot/bind_offset 的 or 链回落、effect_track.spawn 的 kind 载荷。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):describe/it 拍平为 TestBoardFeedbackEffectPlayer,
-- 断言走 support.assert_eq / lu.assertXxx,用例数与改写前一一对应(4 例)。
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local effect_player = require("src.ui.render.board_feedback.effect_player")
local effect_track = require("src.ui.render.support.effect_track")
local runtime_constants = require("src.config.gameplay.runtime_constants")

-- host_runtime 直桩:play_sfx_by_key 七参全捕获,bind_sfx_to_unit 全捕获。
local function _make_host(overrides)
  local captured = { plays = {}, binds = {} }
  local host = {
    play_sfx_by_key = function(effect_id, pos, rot, scale, duration, rate, with_sound)
      captured.plays[#captured.plays + 1] = {
        effect_id = effect_id,
        rot = rot,
        scale = scale,
        duration = duration,
        rate = rate,
        with_sound = with_sound,
      }
      return 100 + #captured.plays
    end,
    bind_sfx_to_unit = function(sfx_id, unit, socket_name, offset, bind_type)
      captured.binds[#captured.binds + 1] = {
        sfx_id = sfx_id,
        socket_name = socket_name,
        offset = offset,
        bind_type = bind_type,
      }
    end,
  }
  for key, value in pairs(overrides or {}) do
    host[key] = value
  end
  return host, captured
end

TestBoardFeedbackEffectPlayer = {}

function TestBoardFeedbackEffectPlayer:test_payload_with_sound_false_wins_over_the_cue_default()
  -- kills _resolve_with_sound 的 ==->~=:payload 显式 false 不许被 cue 值顶掉。
  local host, captured = _make_host()
  local played = effect_player.play("sparkle", { effect_id = 7, with_sound = true }, nil, nil,
    { with_sound = false }, host)
  _assert_eq(played, true, "play should succeed")
  _assert_eq(captured.plays[1].with_sound, false, "payload with_sound=false must win over the cue")
end

function TestBoardFeedbackEffectPlayer:test_rot_falls_back_to_q_zero_when_neither_payload_nor_cue_provides_one()
  -- kills _effect_rot 双 or->and:payload 在场但无 rot 时取 cue.rot,
  -- 全无 rot 时回落 q_zero 而非 nil。
  local host, captured = _make_host()
  local played = effect_player.play("sparkle", { effect_id = 7 }, nil, nil, nil, host)
  _assert_eq(played, true, "play should succeed")
  _assert_eq(captured.plays[1].rot, runtime_constants.q_zero, "missing rot must fall back to q_zero")

  local cue_rot = { marker = "cue_rot" }
  played = effect_player.play("sparkle", { effect_id = 7, rot = cue_rot }, nil, nil, {}, host)
  _assert_eq(played, true, "play with a bare payload should succeed")
  _assert_eq(captured.plays[2].rot, cue_rot, "a payload without rot must fall back to the cue rot")
end

function TestBoardFeedbackEffectPlayer:test_bind_offset_falls_back_to_v3_one_when_the_cue_omits_it()
  -- kills _bind_sfx_to_player 的 or->and:bind_offset 缺省必须回落 v3_one。
  local host, captured = _make_host()
  local unit = { marker = "unit" }
  local played = effect_player.play("sparkle",
    { effect_id = 7, bind_to_player = true, socket_name = "root" }, nil, unit, nil, host)
  _assert_eq(played, true, "play should succeed")
  _assert_eq(#captured.binds, 1, "bound cue should bind to the unit")
  _assert_eq(captured.binds[1].offset, runtime_constants.v3_one,
    "missing bind_offset must fall back to v3_one")
end

function TestBoardFeedbackEffectPlayer:test_skips_binding_when_the_host_has_no_bind_method()
  local host, captured = _make_host()
  host.bind_sfx_to_unit = nil
  local unit = { marker = "unit" }

  local played = effect_player.play("sparkle",
    { effect_id = 7, bind_to_player = true, socket_name = "root" }, nil, unit, nil, host)

  _assert_eq(played, true, "play should still succeed without the bind method")
  _assert_eq(#captured.binds, 0, "no bind call should be attempted without the host method")
end

function TestBoardFeedbackEffectPlayer:test_spawns_the_effect_track_with_the_effect_kind()
  -- kills effect_track.spawn 的 "effect" -> nil。
  local host = _make_host()
  local spawned = {}
  _with_patches({
    { target = effect_track, key = "spawn", value = function(id, kind, duration)
      spawned[#spawned + 1] = { id = id, kind = kind, duration = duration }
    end },
  }, function()
    effect_player.play("sparkle", { effect_id = 7 }, nil, nil, nil, host)
  end)
  _assert_eq(#spawned, 1, "play should spawn one effect track")
  _assert_eq(spawned[1].kind, "effect", "the track kind must be effect")
end


return TestBoardFeedbackEffectPlayer
