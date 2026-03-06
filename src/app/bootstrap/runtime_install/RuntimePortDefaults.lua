local runtime_port_defaults = {}
local number_utils = require("src.core.NumberUtils")

function runtime_port_defaults.build()
  return {
    rng_next_int = function(min, max)
      assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
      return GameAPI.random_int(min, max)
    end,
    schedule = function(delay, fn)
      assert(type(fn) == "function", "schedule requires callback")
      assert(SetTimeOut ~= nil, "missing SetTimeOut")
      SetTimeOut(delay or 0, fn)
    end,
    mark_role_lose = function(role)
      if role and role.lose then
        role.lose()
      end
    end,
    wall_now_seconds = function()
      if GameAPI and type(GameAPI.get_timestamp) == "function" then
        local ok, ts = pcall(GameAPI.get_timestamp)
        if ok and number_utils.is_numeric(ts) then
          return ts
        end
      end
      return 0
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      if GameAPI
          and type(GameAPI.get_timestamp_diff) == "function"
          and number_utils.is_numeric(timestamp_1)
          and number_utils.is_numeric(timestamp_2) then
        local ok, diff = pcall(GameAPI.get_timestamp_diff, timestamp_1, timestamp_2)
        if ok and number_utils.is_numeric(diff) then
          return diff
        end
      end
      if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
    cpu_now_seconds = function()
      if GameAPI and type(GameAPI.get_timestamp) == "function" then
        local ok, ts = pcall(GameAPI.get_timestamp)
        if ok and number_utils.is_numeric(ts) then
          return ts
        end
      end
      return 0
    end,
    cpu_diff_seconds = function(timestamp_1, timestamp_2)
      if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
    resolve_market_paid_gateway = function()
      return require("src.app.bootstrap.payment.EggyPaidPurchaseGateway")
    end,
  }
end

return runtime_port_defaults
