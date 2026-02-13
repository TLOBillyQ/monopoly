local action_anim = require("src.presentation.render.ActionAnim")

local function _build_state()
  local state = {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            return math.Vector3(0.0, 0.0, 0.0)
          end,
        },
      },
    },
    game = {
      board = {
        get_tile = function()
          return { name = "测试地块" }
        end,
      },
      find_player_by_id = function()
        return { position = 1, name = "测试玩家" }
      end,
    },
  }
  return state
end

local function _test_action_anim_overlay_handler_returns_duration()
  local state = _build_state()
  local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  assert(duration == 0.2, "roadblock duration should be used")
end

return {
  _test_action_anim_overlay_handler_returns_duration,
}
