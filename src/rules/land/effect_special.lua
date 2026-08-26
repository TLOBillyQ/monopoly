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
version=4
projectHash=8a4234aae5ddd7e8
scope.0.id=chunk:src/rules/land/effect_special.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=f29fd04a250c0452
scope.1.id=function:_detention_executor
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=13
scope.1.semanticHash=b90741302460d7b0
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=6
scope.2.endLine=8
scope.2.semanticHash=6ccd91ebdf237cf1
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=9
scope.3.endLine=11
scope.3.semanticHash=713e373fad31bfcb
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=23
scope.4.semanticHash=22af3a2490ca6245
scope.5.id=function:<anonymous>#4
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=44
scope.5.semanticHash=e5416c9e14248ce6
]]
