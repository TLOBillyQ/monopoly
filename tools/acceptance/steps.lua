local number_utils = require("src.foundation.number")

local steps = {}

local function _handlers()
  return {
    ["project acceptance step handlers are loaded"] = function(world)
      world.handlers_loaded = true
      return true
    end,

    ["a text value <raw>"] = function(world, example)
      world.raw_text = example.raw
      return true
    end,

    ["the project converts it to an integer"] = function(world)
      world.integer_result = number_utils.to_integer(world.raw_text)
      return true
    end,

    ["the integer result is <result>"] = function(world, example)
      if world.handlers_loaded ~= true then
        return nil, "acceptance step handlers were not loaded"
      end

      local expected = number_utils.to_integer(example.result)
      if expected == nil then
        return nil, "expected result is not an integer: " .. tostring(example.result)
      end
      if world.integer_result ~= expected then
        return nil, "expected " .. tostring(expected) .. ", got " .. tostring(world.integer_result)
      end
      return true
    end,
  }
end

function steps.handlers()
  return _handlers()
end

return steps
