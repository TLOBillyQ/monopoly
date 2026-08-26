local lu = require("luaunit")
local property = require("test.support.property")
local choice_options = require("src.ui.view.choice_options")

-- Identities (table-option ids and scalar-option values) are drawn from one
-- shared distinct pool so every lookup in a generated choice is unambiguous:
-- no two options can share an id, and the "missing id" probe is guaranteed
-- absent.
local ID_POOL_BOUND = 500

local function _take_distinct_id(rng, used)
  local id
  repeat
    id = rng:int(1, ID_POOL_BOUND)
  until not used[id]
  used[id] = true
  return id
end

-- Build a choice whose options mix three shapes the resolvers must handle:
-- table options with a label, table options without a label, and bare scalar
-- options. Returns the choice plus bookkeeping the properties assert against.
local function _gen_choice(rng)
  local count = rng:int(0, 6)
  local used = {}
  local options = {}
  local table_ids = {}
  local scalar_ids = {}
  for index = 1, count do
    local id = _take_distinct_id(rng, used)
    local shape = rng:int(1, 3)
    if shape == 1 then
      options[index] = { id = id, label = "label-" .. tostring(id) }
      table_ids[#table_ids + 1] = id
    elseif shape == 2 then
      options[index] = { id = id }
      table_ids[#table_ids + 1] = id
    else
      options[index] = id
      scalar_ids[#scalar_ids + 1] = id
    end
  end
  return {
    choice = { options = options },
    used = used,
    table_ids = table_ids,
    scalar_ids = scalar_ids,
  }
end

-- describe("choice_options properties") 拍平为文件级 TestChoiceOptions,断言
-- 词汇从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(6 例)。
TestChoiceOptions = {}

function TestChoiceOptions:test_resolve_option_id_is_the_identity_for_scalars_and_the_id_for_table_options()
  property.for_all(function(rng)
    if rng:bool() then
      return { option = rng:int(-ID_POOL_BOUND, ID_POOL_BOUND), is_table = false }
    end
    local id = rng:int(-ID_POOL_BOUND, ID_POOL_BOUND)
    return { option = { id = id, label = "x" }, is_table = true, id = id }
  end, function(case)
    local resolved = choice_options.resolve_option_id(case.option)
    if case.is_table then
      lu.assertEvalToTrue(resolved == case.id, "table option should resolve to its id field")
    else
      lu.assertEvalToTrue(resolved == case.option, "scalar option should resolve to itself")
    end
  end)
end

function TestChoiceOptions:test_resolve_option_by_id_round_trips_every_table_option_back_to_itself()
  property.for_all(_gen_choice, function(case)
    for _, id in ipairs(case.table_ids) do
      local found = choice_options.resolve_option_by_id(case.choice, id)
      lu.assertEvalToTrue(found ~= nil, "a present table id must resolve to an option")
      lu.assertEvalToTrue(choice_options.resolve_option_id(found) == id,
        "the resolved option must carry the looked-up id")
    end
  end)
end

function TestChoiceOptions:test_resolve_option_by_id_never_returns_a_scalar_option()
  property.for_all(_gen_choice, function(case)
    for _, id in ipairs(case.scalar_ids) do
      lu.assertEvalToTrue(choice_options.resolve_option_by_id(case.choice, id) == nil,
        "scalar options are not returned as table options")
    end
  end)
end

function TestChoiceOptions:test_a_present_id_always_yields_a_non_nil_label_and_an_absent_id_yields_nil()
  property.for_all(function(rng)
    return _gen_choice(rng)
  end, function(case, rng)
    for id in pairs(case.used) do
      lu.assertEvalToTrue(choice_options.resolve_option_label_by_id(case.choice, id) ~= nil,
        "every present option id should resolve to a label")
    end
    local missing
    repeat
      missing = rng:int(ID_POOL_BOUND + 1, ID_POOL_BOUND * 2)
    until not case.used[missing]
    lu.assertEvalToTrue(choice_options.resolve_option_by_id(case.choice, missing) == nil,
      "an absent id must not resolve to an option")
    lu.assertEvalToTrue(choice_options.resolve_option_label_by_id(case.choice, missing) == nil,
      "an absent id must not resolve to a label")
  end)
end

function TestChoiceOptions:test_a_missing_or_non_table_options_field_short_circuits_the_id_resolvers_to_nil()
  property.for_all(function(rng)
    return rng:pick({ "absent", "false", "number", "string" })
  end, function(kind, rng)
    local choice
    if kind == "absent" then
      choice = {}
    elseif kind == "false" then
      choice = { options = false }
    elseif kind == "number" then
      choice = { options = rng:int(1, 99) }
    else
      choice = { options = "not-a-table" }
    end
    local id = rng:int(1, 9)
    lu.assertEvalToTrue(choice_options.resolve_option_by_id(choice, id) == nil,
      "a non-table options field resolves to nil")
    lu.assertEvalToTrue(choice_options.resolve_option_label_by_id(choice, id) == nil,
      "a non-table options field resolves to no label")
  end)
end

function TestChoiceOptions:test_the_resolvers_stay_inert_for_nil_empty_inputs()
  lu.assertEvalToTrue(choice_options.resolve_option_by_id(nil, 1) == nil)
  lu.assertEvalToTrue(choice_options.resolve_option_by_id({ options = {} }, nil) == nil)
  lu.assertEvalToTrue(choice_options.resolve_option_label_by_id({ options = {} }, 7) == nil)
  for _, option in ipairs({ false, 0, "", "x", 7 }) do
    lu.assertEvalToTrue(choice_options.resolve_option_id(option) == option,
      "a non-table option resolves to itself")
  end
end


return TestChoiceOptions
