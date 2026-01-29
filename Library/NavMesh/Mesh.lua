local QuadTree = require "Library.NavMesh.QuadTree"

---@class NavMesh.Mesh : NavMesh.QuadTree
local Mesh = Class("NavMesh.Mesh", QuadTree)

---@param boundary Boundary 边界
---@param capacity integer 容量
function Mesh:init(boundary, capacity)
    QuadTree.init(self, boundary, capacity)
end

---@override
---@param node NavMesh.Node 点
function Mesh:insert(node)
    QuadTree.insert(self, node)
    self.last_node = node

    return true
end

return Mesh
