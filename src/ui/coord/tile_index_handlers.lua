-- tile 索引定位事件处理器(自 event_handlers.lua 拆分,行为保持):踩雷/地块
-- 命中的 payload→棋盘索引解析,返回索引供事件消费方使用。
local tile_index_handlers = {}
local context = { state = nil }

local function _event_data(data)
  if type(data) == "table" then
    return data
  end
  return nil
end

local function _resolve_tile_id(payload)
  if type(payload) ~= "table" then
    return nil
  end
  if payload.tile and payload.tile.id then
    return payload.tile.id
  end
  return payload.tile_id
end

local function _board_from_context()
  local ctx = context.state
  return ctx and ctx.game and ctx.game.board or nil
end

local function _index_of_tile_id_from_context(tile_id)
  local board = _board_from_context()
  if tile_id == nil or type(board and board.index_of_tile_id) ~= "function" then
    return nil
  end
  return board:index_of_tile_id(tile_id)
end

local function _resolve_tile_index_from_payload(payload)
  if type(payload) ~= "table" then
    return nil
  end
  if payload.tile_index ~= nil then
    return payload.tile_index
  end
  return _index_of_tile_id_from_context(_resolve_tile_id(payload))
end

function tile_index_handlers.set_context(state)
  context.state = state
end

function tile_index_handlers.install(register_handler, monopoly_event)
  register_handler(monopoly_event.movement.roadblock_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)

  register_handler(monopoly_event.land.mine_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)
end

return tile_index_handlers

--[[ mutate4lua-manifest
version=4
projectHash=02b1126bba21b9b0
scope.0.id=chunk:src/ui/coord/tile_index_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=61
scope.0.semanticHash=08b177701e2da827
scope.1.id=function:_event_data
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=e5984887eaa027c5
scope.2.id=function:_resolve_tile_id
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=21
scope.2.semanticHash=33d43f8fd9a1efff
scope.3.id=function:_board_from_context
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=26
scope.3.semanticHash=b54a5f5004f32012
scope.4.id=function:_index_of_tile_id_from_context
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=34
scope.4.semanticHash=c8f411d47890d79d
scope.5.id=function:_resolve_tile_index_from_payload
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=44
scope.5.semanticHash=221932defca82cae
scope.6.id=function:tile_index_handlers.set_context
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=48
scope.6.semanticHash=a9d82726f0169db1
scope.7.id=function:tile_index_handlers.install
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=58
scope.7.semanticHash=6abfa1121515102e
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=51
scope.8.endLine=53
scope.8.semanticHash=535dada822144f33
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=55
scope.9.endLine=57
scope.9.semanticHash=535dada822144f33
]]
