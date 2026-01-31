---@class NavMesh.Edge
---@field sfx? SfxID
---@field nodeA NavMesh.Node
---@field nodeB NavMesh.Node
---@field length Fixed 长度
---@field new fun(self: NavMesh.Edge, nodeA: NavMesh.Node, nodeB: NavMesh.Node): NavMesh.Edge 创建新的边
local Edge = Class("NavMesh.Edge")
local EdgeList = {}

---@param nodeA NavMesh.Node
---@param nodeB NavMesh.Node
function Edge:init(nodeA, nodeB)
    self.nodeA = nodeA
    self.nodeB = nodeB
    self.length = (nodeA.position - nodeB.position):length()
    table.insert(EdgeList, self)
end

---@param node NavMesh.Node 出发节点
---@return NavMesh.Node
function Edge:get_to_node(node)
    if node == self.nodeA then
        return self.nodeB
    elseif node == self.nodeB then
        return self.nodeA
    else
        error("Node is not in edge")
    end
end

function Edge:render()
    local NavMesh = require "Library.NavMesh.__init"
    if not NavMesh.is_rendering then
        return
    end
    local a_pos = self.nodeA.position
    local b_pos = self.nodeB.position
    local direction = b_pos - a_pos
    local length = direction:length()
    direction:normalize()
    local pitch = math.asin(direction.y)
    local yaw = math.atan2(direction.x, direction.z)
    local yaw_deg = math.rad_to_deg(yaw)
    if yaw_deg < 0 and yaw_deg > - 180 then
        pitch = -pitch
    end
    if not self.sfx then
        self.sfx = GameAPI.play_sfx_by_key(
            21534,
            a_pos + (direction / 5),
            math.Quaternion(pitch, yaw + math.deg_to_rad(-90), pitch),
            1.0,
            -1.0
        )
    end
    GlobalAPI.set_sfx_scale(self.sfx, math.Vector3(length / 50.0, 0.2, 0.10))
    GlobalAPI.set_sfx_visible(self.sfx, true)
end

function Edge:disable_render()
    if self.sfx then
        GlobalAPI.set_sfx_visible(self.sfx, false)
    end
end

function Edge:destroy()
    if self.sfx then
        GlobalAPI.destroy_sfx(self.sfx)
    end
    self.nodeA = nil
    self.nodeB = nil
    self.length = nil
end

return Edge
