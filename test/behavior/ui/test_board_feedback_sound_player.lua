local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local sound_player = require("src.ui.render.board_feedback.sound_player")
local cue_refs = require("src.ui.render.board_feedback.cue_refs")

TestBoardFeedbackSoundPlayer = {}

function TestBoardFeedbackSoundPlayer:test_play_followups_ignores_non_table_entries()
  local played = sound_player.play_followups("cue", { x = 0 }, { "not-a-table" }, {
    play_3d_sound = function()
      return 1
    end,
    schedule = function() end,
  })

  _assert_eq(played, false, "non-table entries should not schedule anything")
end

function TestBoardFeedbackSoundPlayer:test_play_followups_requires_play_3d_sound()
  local played = sound_player.play_followups("cue", { x = 0 }, { { sound_id = 1 } }, {
    schedule = function() end,
  })

  _assert_eq(played, false, "missing play_3d_sound should skip scheduling")
end

function TestBoardFeedbackSoundPlayer:test_play_followups_warns_and_skips_invalid_sound_ids()
  local warns = {}
  local host = {
    play_3d_sound = function()
      return 1
    end,
    schedule = function(_, fn)
      fn()
    end,
  }

  _with_patches({
    {
      target = cue_refs,
      key = "warn_missing_ref_once",
      value = function(kind, cue_name, ref_value, reason)
        warns[#warns + 1] = {
          kind = kind,
          cue_name = cue_name,
          ref_value = ref_value,
          reason = reason,
        }
      end,
    },
  }, function()
    local played = sound_player.play_followups("cue", { x = 0 }, {
      { sound_id = nil, sound_id_ref = "sfx_missing" },
      { sound_id = 0, sound_id_ref = "sfx_zero" },
    }, host)

    _assert_eq(played, true, "invalid entries should still report the followup scheduled")
  end)

  _assert_eq(#warns, 2, "each invalid sound id should warn once")
  _assert_eq(warns[1].reason, "missing_or_unconfigured", "warn reason should be missing_or_unconfigured")
  _assert_eq(warns[1].kind, "sound", "warn kind should be the cue kind")
  _assert_eq(warns[2].kind, "sound", "warn kind should be the cue kind")
end

function TestBoardFeedbackSoundPlayer:test_play_followups_valid_sound_id_plays_with_zero_delay()
  -- 杀 L19 delay 兜底 0->1 与 L22 sound_id 边界 0->1:有效 id=1 必须真播,
  -- 缺省 delay 必须按 0 调度(不能默认 1)。
  local played_args = nil
  local scheduled_delays = {}
  local host = {
    play_3d_sound = function(pos, sound_id, duration, volume)
      played_args = { pos, sound_id, duration, volume }
      return 1
    end,
    schedule = function(delay, fn)
      scheduled_delays[#scheduled_delays + 1] = delay
      fn()
    end,
  }

  local played = sound_player.play_followups("cue", { x = 1 }, {
    { sound_id = 1 },
  }, host)

  _assert_eq(played, true, "valid sound id should report scheduled")
  _assert_eq(#scheduled_delays, 1, "one followup should schedule one step")
  _assert_eq(scheduled_delays[1], 0, "missing delay should default to 0")
  _assert_eq(played_args ~= nil, true, "valid sound id should reach play_3d_sound")
  _assert_eq(played_args[2], 1, "the played sound id should be the entry's")
  _assert_eq(played_args[3], 1.0, "missing duration should default to 1.0")
  _assert_eq(played_args[4], 1.0, "missing volume should default to 1.0")
end

function TestBoardFeedbackSoundPlayer:test_play_resolves_explicit_payload_over_cue_fields()
  -- _resolve_sound_params 取值链:payload 显式值 > cue 字段 > 兜底。
  -- 显式值场景杀 L40(or->and)、L41 第一个 or->and、L51/L52 的
  -- 整调用->nil / _payload_or_cue->nil / key->nil 三类参数位点。
  local played_args = nil
  local host = {
    play_3d_sound = function(pos, sound_id, duration, volume)
      played_args = { pos, sound_id, duration, volume }
      return 1
    end,
  }
  local cue = { sound_id = 5, sound_duration = 2.0, duration = 3.0, volume = 0.5 }
  local payload = { sound_duration = 4.0, volume = 0.25 }

  local ok = sound_player.play("cue", cue, { x = 9 }, payload, host)

  _assert_eq(ok, true, "a valid cue should play")
  _assert_eq(played_args[2], 5, "sound id should come from the cue")
  _assert_eq(played_args[3], 4.0, "explicit payload duration should win over cue fields")
  _assert_eq(played_args[4], 0.25, "explicit payload volume should win over cue fields")
end

function TestBoardFeedbackSoundPlayer:test_play_falls_back_to_cue_field_when_payload_missing()
  -- explicit 缺省时回落 cue 字段:杀 L41 第二个 or->and——
  -- 变异 `explicit or (cue_field and cue_fallback)` 会错误落到 fallback。
  local played_args = nil
  local host = {
    play_3d_sound = function(pos, sound_id, duration, volume)
      played_args = { pos, sound_id, duration, volume }
      return 1
    end,
  }
  local cue = { sound_id = 5, sound_duration = 2.0, duration = 3.0, volume = 0.5 }

  local ok = sound_player.play("cue", cue, { x = 9 }, {}, host)

  _assert_eq(ok, true, "a valid cue should play")
  _assert_eq(played_args[3], 2.0, "cue sound_duration should win when payload is empty")
  _assert_eq(played_args[4], 0.5, "cue volume should win when payload is empty")
end


return TestBoardFeedbackSoundPlayer
