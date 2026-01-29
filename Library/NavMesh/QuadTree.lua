---@class NavMesh.QuadTree
---@field boundary Boundary 边界
---@field capacity integer 容量
---@field nodes NavMesh.Node[] 点
---@field divided boolean 是否已划分
---@field northwest NavMesh.QuadTree? 西北子节点
---@field northeast NavMesh.QuadTree? 东北子节点
---@field southwest NavMesh.QuadTree? 西南子节点
---@field southeast NavMesh.QuadTree? 东南子节点
---@field new fun(self: NavMesh.QuadTree, boundary: Boundary, capacity?: integer): NavMesh.QuadTree 创建新的四叉树节点
local QuadTree = Class("NavMesh.QuadTree")

---@alias Boundary {x: Fixed, z: Fixed, width: Fixed, height: Fixed}

-- 辅助函数：计算两点之间的距离（忽略 y 坐标）
---@param a Vector3
---@param b Vector3
---@return Fixed
local function squaredDistance2D(a, b)
    return (a - b):length()
end

-- 创建新的四叉树节点
---@param boundary Boundary 边界
---@param capacity? integer 容量
function QuadTree:init(boundary, capacity)
    if not boundary then
        error("Boundary is required")
    end
    capacity = capacity or 4
    self.boundary = boundary
    self.capacity = capacity
    self.nodes = {}
    self.divided = false
end

-- 将四叉树节点划分为四个子节点
function QuadTree:subdivide()
    local x = self.boundary.x
    local z = self.boundary.z
    local w = self.boundary.width / 2
    local h = self.boundary.height / 2

    local nw = { x = x - w / 2, z = z - h / 2, width = w, height = h }
    local ne = { x = x + w / 2, z = z - h / 2, width = w, height = h }
    local sw = { x = x - w / 2, z = z + h / 2, width = w, height = h }
    local se = { x = x + w / 2, z = z + h / 2, width = w, height = h }

    self.northwest = QuadTree:new(nw, self.capacity)
    self.northeast = QuadTree:new(ne, self.capacity)
    self.southwest = QuadTree:new(sw, self.capacity)
    self.southeast = QuadTree:new(se, self.capacity)

    self.divided = true
end

-- 检查点是否在边界内
---@param point Vector3 点
---@return boolean Status 是否在边界内
function QuadTree:contains(point)
    return point.x >= self.boundary.x - self.boundary.width / 2 and
        point.x <= self.boundary.x + self.boundary.width / 2 and
        point.z >= self.boundary.z - self.boundary.height / 2 and
        point.z <= self.boundary.z + self.boundary.height / 2
end

-- 将点插入四叉树
---@param node NavMesh.Node 点
---@return boolean Status 是否成功插入
function QuadTree:insert(node)
    if not self:contains(node.position) then
        return false
    end

    if #self.nodes < self.capacity then
        table.insert(self.nodes, node)
        return true
    end

    if not self.divided then
        self:subdivide()
    end

    if self.northwest and self.northwest:insert(node) then return true end
    if self.northeast and self.northeast:insert(node) then return true end
    if self.southwest and self.southwest:insert(node) then return true end
    if self.southeast and self.southeast:insert(node) then return true end

    return false
end

-- 将点移出四叉树
---@param node NavMesh.Node 点
function QuadTree:remove(node)
    -- 检查当前节点的点
    for i, n in ipairs(self.nodes) do
        if n == node then
            table.remove(self.nodes, i)
            break
        end
    end

    -- 递归检查子节点
    if self.divided then
        if self.northwest then self.northwest:remove(node) end
        if self.northeast then self.northeast:remove(node) end
        if self.southwest then self.southwest:remove(node) end
        if self.southeast then self.southeast:remove(node) end

        -- 检查是否需要合并子节点
        local total_nodes = #self.nodes
        if self.northwest then total_nodes = total_nodes + #self.northwest.nodes end
        if self.northeast then total_nodes = total_nodes + #self.northeast.nodes end
        if self.southwest then total_nodes = total_nodes + #self.southwest.nodes end
        if self.southeast then total_nodes = total_nodes + #self.southeast.nodes end

        -- 如果总节点数不超过容量且子节点未被进一步划分，则合并
        if total_nodes <= self.capacity and
            (not self.northwest or not self.northwest.divided) and
            (not self.northeast or not self.northeast.divided) and
            (not self.southwest or not self.southwest.divided) and
            (not self.southeast or not self.southeast.divided) then
            -- 合并子节点的点
            if self.northwest then
                for _, n in ipairs(self.northwest.nodes) do
                    table.insert(self.nodes, n)
                end
            end
            if self.northeast then
                for _, n in ipairs(self.northeast.nodes) do
                    table.insert(self.nodes, n)
                end
            end
            if self.southwest then
                for _, n in ipairs(self.southwest.nodes) do
                    table.insert(self.nodes, n)
                end
            end
            if self.southeast then
                for _, n in ipairs(self.southeast.nodes) do
                    table.insert(self.nodes, n)
                end
            end

            -- 清除子节点
            self.northwest = nil
            self.northeast = nil
            self.southwest = nil
            self.southeast = nil
            self.divided = false
        end
    end
    node:destroy()
end

-- 查询最近的点
---@param point Vector3 点
---@param best_node NavMesh.Node? 最近的点
---@param best_dist_sq Fixed? 距离阈值（可选）
---@return NavMesh.Node? 最近的点
---@return Fixed? 点间距离
function QuadTree:query_nearest(point, best_node, best_dist_sq)
    local best_node = best_node or nil --[[@as NavMesh.Node?]]
    best_dist_sq = best_dist_sq or math.maxval

    -- 检查当前节点的点
    for _, n in ipairs(self.nodes) do
        local dist_sq = squaredDistance2D(point, n.position)
        if dist_sq < best_dist_sq then
            best_node = n
            best_dist_sq = dist_sq
        end
    end

    -- 确定要检查哪些子节点
    if self.divided then
        local children = {
            self.northwest, self.northeast,
            self.southwest, self.southeast
        }

        for _, child in ipairs(children) do
            best_node, best_dist_sq = child:query_nearest(point, best_node, best_dist_sq)
        end
    end

    return best_node, best_dist_sq
end

return QuadTree
