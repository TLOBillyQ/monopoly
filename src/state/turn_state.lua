local dirty_tracker = require("src.state.dirty_tracker")

local game_state_turn = {}

function game_state_turn.queue_action_anim(self, payload)
  assert(payload ~= nil, "missing action anim payload")
  local seq = (self.turn.action_anim_seq or 0) + 1
  payload.seq = seq
  self.turn.action_anim_seq = seq
  local queue = self.turn.action_anim_queue
  if type(queue) ~= "table" then
    queue = {}
    self.turn.action_anim_queue = queue
  end
  queue[#queue + 1] = payload
  if not self.turn.action_anim then
    self.turn.action_anim = table.remove(queue, 1)
  end
  dirty_tracker.mark(self.dirty, "turn")
  return payload
end

function game_state_turn.queue_move_anim(self, payload)
  assert(payload ~= nil, "missing move anim payload")
  local seq = (self.turn.move_anim_seq or 0) + 1
  payload.seq = seq
  self.turn.move_anim_seq = seq
  self.turn.move_anim = payload
  dirty_tracker.mark(self.dirty, "turn")
  return payload
end

function game_state_turn.pending_choice(self)
  return self.turn.pending_choice
end

return game_state_turn

--[[ mutate4lua-manifest
version=2
projectHash=f96f8681f69c0b59
scope.0.id=chunk:src/state/turn_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=53c1488321072edf
scope.1.id=function:game_state_turn.queue_action_anim:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=21
scope.1.semanticHash=724527836342017a
scope.2.id=function:game_state_turn.queue_move_anim:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=31
scope.2.semanticHash=3b4f72fddd4f85c8
scope.3.id=function:game_state_turn.pending_choice:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=35
scope.3.semanticHash=d9460cbb5aba9126
]]
