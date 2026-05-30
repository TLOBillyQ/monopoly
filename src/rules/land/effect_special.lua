local mine_effect = require("src.rules.effects.mine")
local M = {}

local function _detention_executor(tile_type, effect_method)
  return {
    can_apply = function(ctx)
      return ctx.tile and ctx.tile.type == tile_type
    end,
    apply = function(ctx)
      ctx.game[effect_method](ctx.game, ctx.player)
    end,
  }
end

M.executors = {
  hospital = _detention_executor("hospital", "player_apply_hospital_effects"),
  mountain = _detention_executor("mountain", "player_apply_mountain_effects"),
  mine = {
    can_apply = function(ctx)
      local position = ctx.player and ctx.player.position
      local game = ctx.game
      return mine_effect.can_trigger(game, ctx.player, position)
    end,
    apply = function(ctx)
      local player = ctx.player
      local game = ctx.game
      local position = player.position
      local res = mine_effect.apply(game, player, position)
      if res and res.hospitalized then
        if res.wait_action_anim == true then
          return {
            waiting = true,
            wait_action_anim = true,
            next_state = res.next_state,
            next_args = res.next_args,
          }
        end
        return {
          kind = "need_landing",
          player_id = player.id,
          board_index = player.position,
        }
      end
    end,
  },
}

return M

--[[ mutate4lua-manifest
version=2
projectHash=21455f4d45e2fdbd
scope.0.id=chunk:src/rules/land/effect_special.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=55
scope.0.semanticHash=21940bdc22359ed9
scope.1.id=function:anonymous@8:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=3114d613f1abbc6a
scope.2.id=function:anonymous@11:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=17
scope.2.semanticHash=21cdc4f208c57610
scope.3.id=function:_detention_executor:6
scope.3.kind=function
scope.3.startLine=6
scope.3.endLine=19
scope.3.semanticHash=fb6391a0b9393497
scope.4.id=function:anonymous@25:25
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=29
scope.4.semanticHash=711b9f5e1de549f0
scope.5.id=function:anonymous@30:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=50
scope.5.semanticHash=5dd3a930882bd194
]]
