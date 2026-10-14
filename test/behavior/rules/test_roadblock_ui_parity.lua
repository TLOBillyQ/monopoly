require("test.bootstrap").install_package_paths()
-- luacheck: ignore 143 (busted injects the verified luassert object)
local luassert = assert
-- #105 回归:电脑路障候选口径 ⊆ 真人 UI 接纳口径(is_ui_candidate)。
-- 证据基线是 #104 报告的代表位置(5/34/36/40/43 等岔口与内环附近),
-- 两侧路径(executor.use_item 直放、choice 结算)都走真实模块。
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local roadblock = require("src.rules.items.roadblock")
local executor = require("src.rules.items.executor")
local choice_resolver = require("src.rules.choice.resolver")
local item_ids = require("src.config.gameplay.item_ids")
local agent = require("src.computer.agent")
local _config_reset = require("test.support.config_reset")

-- #104 报告中存在电脑专属格的代表位置(棋盘下标)。
-- dir 用 "none" 代 nil:字面 nil 会让 ipairs 提前收尾。
local PARITY_POSITIONS = { 5, 34, 36, 40, 43 }
local DIRS = { "none", "up", "down", "left", "right" }

-- #104 端到端实测越界的(位置, 朝向)组合。
local OFFENDING_STATES = {
  { pos = 34, dir = nil },
  { pos = 36, dir = "up" },
  { pos = 40, dir = "down" },
  { pos = 43, dir = "down" },
}

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _cpu_at(g, pos, dir)
  if dir == "none" then
    dir = nil
  end
  local p = g.players[2]
  g:update_player_position(p, pos)
  g:set_player_status(p, "move_dir", dir)
  return p
end

local function _spy_placements(g)
  local placed = {}
  local original = g.place_roadblock
  g.place_roadblock = function(self, idx)
    placed[#placed + 1] = idx
    return original(self, idx)
  end
  return placed
end

describe("TestRoadblockUiParity", function()
  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_auto_candidates_stay_within_ui_acceptance_at_branch_positions", function()
    for _, pos in ipairs(PARITY_POSITIONS) do
      for _, dir in ipairs(DIRS) do
        local g = _new_game()
        local p = _cpu_at(g, pos, dir)
        local cands = roadblock.auto_candidates(g, p, 3)
        for _, cand in ipairs(cands) do
          luassert.truthy(roadblock.is_ui_candidate(g, p, cand.idx, 3),
            "pos=" .. tostring(pos) .. " dir=" .. tostring(dir)
              .. " auto candidate " .. tostring(cand.idx)
              .. " (" .. tostring(cand.tile.name) .. ") escapes human UI acceptance set")
        end
      end
    end
  end)

  it("test_direct_ai_placement_stays_within_ui_acceptance", function()
    for _, state in ipairs(OFFENDING_STATES) do
      local g = _new_game()
      local p = _cpu_at(g, state.pos, state.dir)
      p.inventory:add({ id = item_ids.roadblock })
      local placed = _spy_placements(g)

      local res = executor.use_item(g, p, item_ids.roadblock, { is_computer_controlled = true })
      luassert.truthy(type(res) == "table" and res.ok == true,
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir) .. " direct ai roadblock should settle")
      luassert.is.equal(1, #placed,
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir) .. " should place exactly one roadblock")
      luassert.truthy(roadblock.is_ui_candidate(g, p, placed[1], 3),
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir)
          .. " direct placement " .. tostring(placed[1]) .. " escapes human UI acceptance set")
    end
  end)

  it("test_choice_settlement_accepts_auto_answer_without_deadlock", function()
    for _, state in ipairs(OFFENDING_STATES) do
      local g = _new_game()
      local p = _cpu_at(g, state.pos, state.dir)
      p.inventory:add({ id = item_ids.roadblock })

      local res = executor.use_item(g, p, item_ids.roadblock, { is_computer_controlled = false })
      luassert.truthy(type(res) == "table" and res.waiting == true,
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir) .. " delegated use should open choice")
      local pending = support.open_choice(g, res.intent.choice_spec)

      local action = agent.auto_action_for_choice(g, pending)
      luassert.truthy(action ~= nil,
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir) .. " agent should answer roadblock choice")
      local result = choice_resolver.resolve(g, pending, action)
      luassert.truthy(result.status ~= "rejected",
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir)
          .. " auto answer " .. tostring(action.option_id) .. " must not be rejected (deadlock)")
      luassert.truthy(roadblock.is_ui_candidate(g, p, action.option_id, 3),
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir)
          .. " settled target " .. tostring(action.option_id) .. " escapes human UI acceptance set")
      luassert.truthy(g.board:has_roadblock(action.option_id),
        "pos=" .. state.pos .. " dir=" .. tostring(state.dir) .. " settled target should hold the roadblock")
    end
  end)
end)
