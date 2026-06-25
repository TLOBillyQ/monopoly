local cue_refs = require("src.ui.render.board_feedback.cue_refs")
local logger = require("src.foundation.log")

-- cue_refs warns through logger.warn; capture the calls so the resolution
-- branches (precedence, missing-ref dedup, allow_missing) are observable.
local function _capture_warns(fn)
  local saved = logger.warn
  local calls = {}
  logger.warn = function(...)
    calls[#calls + 1] = { ... }
  end
  local ok, err = pcall(fn, calls)
  logger.warn = saved
  assert(ok, err)
  return calls
end

local function _has_arg(call, needle)
  for _, value in ipairs(call) do
    if value == needle then
      return true
    end
  end
  return false
end

describe("board_feedback cue_refs", function()
  describe("resolve_cue_ref_id precedence", function()
    it("prefers the explicit payload id over cue config and lookup keys", function()
      local id = cue_refs.resolve_cue_ref_id(
        "sparkle",
        { effect_id = 7, effect_lookup_key = "spark" },
        { effect_id = 99 },
        "effect"
      )
      assert(id == 99, "explicit payload id must win, got " .. tostring(id))
    end)

    it("falls back to the cue id when the payload omits it", function()
      local id = cue_refs.resolve_cue_ref_id("sparkle", { effect_id = 42 }, nil, "effect")
      assert(id == 42, "cue id should resolve when payload absent, got " .. tostring(id))
    end)

    it("resolves the lookup key from the payload ref ahead of the cue lookup key", function()
      local calls = _capture_warns(function()
        local id = cue_refs.resolve_cue_ref_id(
          "sparkle",
          { effect_lookup_key = "cue_ref" },
          { effect_id_ref = "payload_ref" },
          "effect"
        )
        assert(id == nil, "an unconfigured lookup ref resolves to nil")
      end)
      assert(#calls == 1, "the missing payload-provided ref should warn once")
      assert(_has_arg(calls[1], "effect_id_ref=payload_ref"),
        "the warned ref should be the payload ref, not the cue lookup key")
    end)

    it("warns exactly once for a repeated identical missing ref", function()
      local calls = _capture_warns(function()
        cue_refs.resolve_cue_ref_id("sparkle", { sound_lookup_key = "echo_once" }, nil, "sound")
        cue_refs.resolve_cue_ref_id("sparkle", { sound_lookup_key = "echo_once" }, nil, "sound")
      end)
      assert(#calls == 1, "an identical missing ref must warn only once, got " .. tostring(#calls))
    end)

    it("skips an empty lookup key, warning unless allow_missing is set", function()
      local warned = _capture_warns(function()
        local id = cue_refs.resolve_cue_ref_id("quiet", { effect_lookup_key = "" }, nil, "effect")
        assert(id == nil, "an empty lookup key resolves to nil")
      end)
      assert(#warned == 1, "a missing lookup key without allow_missing should warn")

      local silent = _capture_warns(function()
        local id = cue_refs.resolve_cue_ref_id(
          "quiet",
          { effect_lookup_key = "", allow_missing = true },
          nil,
          "effect"
        )
        assert(id == nil, "an empty lookup key still resolves to nil with allow_missing")
      end)
      assert(#silent == 0, "allow_missing should suppress the missing-lookup warning")
    end)
  end)

  describe("resolve_sfx_scale", function()
    it("returns the resolved numeric scale when valid", function()
      assert(cue_refs.resolve_sfx_scale("sparkle", 2.5, 1.0) == 2.5)
    end)

    it("falls back to the default scale of 1.0 and warns on a non-numeric value", function()
      local calls = _capture_warns(function()
        local scale = cue_refs.resolve_sfx_scale("sparkle", "nope", nil)
        assert(scale == 1.0, "an invalid scale should fall back to 1.0, got " .. tostring(scale))
      end)
      assert(#calls == 1, "an invalid scale should warn once")
    end)
  end)

  describe("resolve_numeric", function()
    it("passes numeric values through and uses the fallback otherwise", function()
      assert(cue_refs.resolve_numeric(3.0, 9.0) == 3.0)
      assert(cue_refs.resolve_numeric(nil, 9.0) == 9.0)
    end)
  end)
end)
