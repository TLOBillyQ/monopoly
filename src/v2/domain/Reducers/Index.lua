local turn_reducer = require("src.v2.domain.Reducers.TurnReducer")
local choice_reducer = require("src.v2.domain.Reducers.ChoiceReducer")
local board_reducer = require("src.v2.domain.Reducers.BoardReducer")
local player_reducer = require("src.v2.domain.Reducers.PlayerReducer")
local item_reducer = require("src.v2.domain.Reducers.ItemReducer")
local match_reducer = require("src.v2.domain.Reducers.MatchReducer")
local patch_reducer = require("src.v2.domain.Reducers.PatchReducer")

local reducers = {
  turn_reducer,
  choice_reducer,
  board_reducer,
  player_reducer,
  item_reducer,
  match_reducer,
  patch_reducer,
}

local reducer_index = {}

function reducer_index.apply(state, event)
  for _, reducer in ipairs(reducers) do
    reducer.apply(state, event)
  end
end

return reducer_index
