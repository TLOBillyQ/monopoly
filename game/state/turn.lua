local turn = {}

local function _mark_turn(self)
  self.dirty.any = true
  self.dirty.turn = true
end

function turn.queue_action_anim(self, payload)
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
  _mark_turn(self)
  return payload
end

function turn.pending_choice(self)
  return self.turn.pending_choice
end

return turn
