---@class NavMesh.Node
---@field position Vector3
---@field sfx? SfxID
---@field id integer 节点ID
---@field edges NavMesh.Edge[] 边
---@field is_last_node boolean 是否是最后一个节点
---@field destroyed boolean 是否被销毁
---@field new fun(self: NavMesh.Node, position: Vector3): NavMesh.Node 创建新的节点
local Node = Class("NavMesh.Node")
local Edge = require "vendor.third_party.NavMesh.Edge"
local NodeList = {}
local NodeId = 1

---@param position Vector3
function Node:init(position)
    self.destroyed = false
    self.position = position
    self.edges = {}
    self.id = NodeId
    NodeList[NodeId] = self
    NodeId = NodeId + 1
end

---@return NavMesh.Node
function Node.query_node_by_id(id)
    return NodeList[id]
end

---@param node NavMesh.Node 被连接的节点
function Node:connect(node)
    local edge = Edge:new(self, node)
    table.insert(self.edges, edge)
    table.insert(node.edges, edge)
    edge:render()
end

---@param node NavMesh.Node 被检测的点
---@return boolean
function Node:is_connected(node)
    for _, edge in ipairs(self.edges) do
        if edge.nodeB == node or edge.nodeA == node then
            return true
        end
    end
    return false
end

function Node:render()
    local NavMesh = require "vendor.third_party.NavMesh.__init"
    if not NavMesh.is_rendering then
        return
    end
    if self.is_last_node and self.sfx then
        GlobalAPI.destroy_sfx(self.sfx)
        self.sfx = nil
        self.is_last_node = false
    end
    if not self.sfx then
        self.sfx = GameAPI.play_sfx_by_key(21417, self.position, math.Quaternion(0, 0, 0), 1.0, -1.0)
    end
    for _, edge in ipairs(self.edges) do
        edge:render()
    end
    GlobalAPI.set_sfx_visible(self.sfx, true)
end

function Node:render_as_last()
    local NavMesh = require "vendor.third_party.NavMesh.__init"
    if not NavMesh.is_rendering then
        return
    end
    if self.sfx then
        GlobalAPI.destroy_sfx(self.sfx)
        self.sfx = nil
    end
    self.is_last_node = true
    self.sfx = GameAPI.play_sfx_by_key(21416, self.position, math.Quaternion(0, 0, 0), 1.0, -1.0)
end

function Node:disable_render()
    if self.sfx then
        GlobalAPI.set_sfx_visible(self.sfx, false)
    end
    for _, edge in ipairs(self.edges) do
        edge:disable_render()
    end
end

function Node:destroy()
    if self.destroyed then
        return
    end
    if self.sfx then
        GlobalAPI.destroy_sfx(self.sfx)
    end
    for _, edge in ipairs(self.edges) do
        local otherNode = edge.nodeA == self and edge.nodeB or edge.nodeA
        for i, otherEdge in ipairs(otherNode.edges) do
            if otherEdge == edge then
                table.remove(otherNode.edges, i)
                break
            end
        end
        edge:destroy()
    end
    NodeList[self.id] = nil
    self.position = nil
    self.edges = nil
    self.id = nil
    self.is_last_node = nil
    self.sfx = nil
    self.destroyed = true
end

return Node
