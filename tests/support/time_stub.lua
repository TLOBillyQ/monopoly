local patch = require("support.patch")

local time_stub = {}

function time_stub.with_timestamp_stub(fn)
  local now = 0
  local game_api = GameAPI or {}
  return patch.with_patches({
    { key = "GameAPI", value = game_api },
    {
      target = game_api,
      key = "get_timestamp",
      value = function()
        now = now + 1
        return now
      end,
    },
    {
      target = game_api,
      key = "get_timestamp_diff",
      value = function(a, b)
        return a - b
      end,
    },
  }, fn)
end

return time_stub
