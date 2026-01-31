---@class NavMesh.Builder
---@field mesh NavMesh.Mesh
---@field new fun(self: NavMesh.Builder, config: NavMeshBuilderConfig): NavMesh.Builder 创建网格构建器
local Builder = Class("NavMesh.Builder")

---@param config NavMeshBuilderConfig
function Builder:init(config)
    self:init_mesh()
    local Node = require "Library.NavMesh.Node"
    local mapping = {}
    for idx, node_config in ipairs(config.nodes) do
        local position = math.Vector3(node_config[1], node_config[2], node_config[3]) --[[@as Vector3]]
        local node = Node:new(position)
        self.mesh:insert(node)
        mapping[idx] = node
    end
    for idx, node in ipairs(mapping) do
        local connect_ids = config.edges[idx] --[[@as integer[]?]]
        if connect_ids then
            for _, connect_id in pairs(connect_ids) do
                local nodeB = mapping[connect_id] --[[@as NavMesh.Node]]
                node:connect(nodeB)
            end
        end
    end
    mapping = nil
end

function Builder:init_mesh()
    local Mesh = require "Library.NavMesh.Mesh"
    self.mesh = Mesh:new({ x = 0, z = 0, width = 500, height = 500 })
end

return Builder
