---@class NavMesh.Path
local Path = {}

-- 节点比较函数（用于判断两个节点是否相同）
---@param a NavMesh.Node
---@param b NavMesh.Node
local function node_equals(a, b)
    -- 这里假设节点有某种唯一标识符，如果没有，可能需要根据节点属性进行比较
    return a.id == b.id
end

-- 计算两点之间的欧几里得距离（用于A*算法的启发式函数）
---@param node_a NavMesh.Node
---@param node_b NavMesh.Node
local function euclidean_distance(node_a, node_b)
    local length = (node_a.position - node_b.position):length()
    return length
end

-- 重建路径（从终点回溯到起点）
local function reconstruct_path(came_from, current)
    local path = { current.position }
    while came_from[current.id] do
        current = came_from[current.id]
        table.insert(path, 1, current.position)
    end
    return path
end

---@param waypoints Vector3[]
function Path.simplified(waypoints)
    if #waypoints < 2 then return waypoints end

    local newPath = {}
    local currentIndex = 1

    -- 总是添加起点
    table.insert(newPath, waypoints[currentIndex])

    while currentIndex < #waypoints do
        local bestIndex = currentIndex + 1

        -- 从最远点开始反向检查
        for testIndex = #waypoints, currentIndex + 1, -1 do
            -- 射线检测当前点到测试点
            local enable = true
            GameAPI.raycast_unit(waypoints[currentIndex], waypoints[testIndex], {4, 8, 128, 256, 512, 1024, 32768}, function()
                enable = false
            end)
            if enable then
                bestIndex = testIndex
                break
            end
        end

        -- 添加可直达的最远点
        table.insert(newPath, waypoints[bestIndex])
        currentIndex = bestIndex
    end

    return newPath
end

-- A*算法实现
function Path.astar(mesh, start_node, end_node)
    local open_set = { start_node }
    local came_from = {}
    local g_score = { [start_node.id] = 0 }
    local f_score = { [start_node.id] = euclidean_distance(start_node, end_node) }

    while #open_set > 0 do
        -- 找到f值最小的节点
        local current = open_set[1]
        local current_index = 1
        for i, node in ipairs(open_set) do
            if f_score[node.id] and (not f_score[current.id] or f_score[node.id] < f_score[current.id]) then
                current = node
                current_index = i
            end
        end

        -- 如果到达终点，重建路径
        if node_equals(current, end_node) then
            return reconstruct_path(came_from, current)
        end

        -- 从开放集中移除当前节点
        table.remove(open_set, current_index)

        -- 遍历所有邻接节点
        for _, edge in ipairs(current.edges) do
            local neighbor_node = edge:get_to_node(current)
            local neighbor = neighbor_node.id
            local tentative_g_score = g_score[current.id] + edge.length

            if not g_score[neighbor] or tentative_g_score < g_score[neighbor] then
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = g_score[neighbor] + euclidean_distance(neighbor_node, end_node)

                -- 如果邻居不在开放集中，则添加
                local in_open_set = false
                for _, n in ipairs(open_set) do
                    if node_equals(n, neighbor_node) then
                        in_open_set = true
                        break
                    end
                end

                if not in_open_set then
                    table.insert(open_set, neighbor_node)
                end
            end
        end
    end

    return nil -- 没有找到路径
end

-- 迪杰斯特拉算法实现
function Path.dijkstra(mesh, start_node, end_node)
    local dist = { [start_node.id] = 0 }
    local prev = {}
    local queue = { start_node }

    while #queue > 0 do
        -- 找到距离最小的节点
        local current = queue[1]
        local current_index = 1
        for i, node in ipairs(queue) do
            if dist[node.id] and (not dist[current.id] or dist[node.id] < dist[current.id]) then
                current = node
                current_index = i
            end
        end

        -- 如果到达终点，重建路径
        if node_equals(current, end_node) then
            return reconstruct_path(prev, current)
        end

        -- 从队列中移除当前节点
        table.remove(queue, current_index)

        -- 遍历所有邻接节点
        for _, edge in ipairs(current.edges) do
            local neighbor_node = edge:get_to_node(current)
            local neighbor = neighbor_node.id
            local alt = dist[current] + edge.length

            if not dist[neighbor] or alt < dist[neighbor] then
                dist[neighbor] = alt
                prev[neighbor] = current

                -- 如果邻居不在队列中，则添加
                local in_queue = false
                for _, n in ipairs(queue) do
                    if node_equals(n, neighbor_node) then
                        in_queue = true
                        break
                    end
                end

                if not in_queue then
                    table.insert(queue, neighbor)
                end
            end
        end
    end

    return nil -- 没有找到路径
end

-- 广度优先搜索实现
function Path.bfs(mesh, start_node, end_node)
    local queue = { start_node }
    local visited = { [start_node.id] = true }
    local came_from = { [start_node.id] = nil }

    while #queue > 0 do
        local current = table.remove(queue, 1)

        -- 如果到达终点，重建路径
        if node_equals(current, end_node) then
            return reconstruct_path(came_from, current)
        end

        -- 遍历所有邻接节点
        for _, edge in ipairs(current.edges) do
            local neighbor = edge:get_to_node(current).id

            if not visited[neighbor] then
                visited[neighbor] = true
                came_from[neighbor] = current
                table.insert(queue, neighbor)
            end
        end
    end

    return nil -- 没有找到路径
end

-- 深度优先搜索实现
function Path.dfs(mesh, start_node, end_node)
    local stack = { start_node }
    local visited = { [start_node] = true }
    local came_from = { [start_node] = nil }

    while #stack > 0 do
        local current = table.remove(stack)

        -- 如果到达终点，重建路径
        if node_equals(current, end_node) then
            return reconstruct_path(came_from, current)
        end

        -- 遍历所有邻接节点
        for _, edge in ipairs(current.edges) do
            local neighbor = edge:get_to_node(current)

            if not visited[neighbor] then
                visited[neighbor] = true
                came_from[neighbor] = current
                table.insert(stack, neighbor)
            end
        end
    end

    return nil -- 没有找到路径
end

---@enum Path.Algorithm
local Algorithm = {
    AStar = "astar",
    Dijkstra = "dijkstra",
    BFS = "bfs",
    DFS = "dfs"
}

-- 策略模式查询函数
---@param algorithm Path.Algorithm
---@param mesh NavMesh.Mesh
---@param start_point Vector3
---@param end_point Vector3
---@return NavMesh.Node[]?
function Path.query(algorithm, mesh, start_point, end_point)
    -- 将坐标转换为最近的节点
    local start_node = mesh:query_nearest(start_point)
    local end_node = mesh:query_nearest(end_point)

    if not start_node or not end_node then
        return nil
    end

    -- 根据算法名称选择对应的搜索方法
    local search_func
    if algorithm == "astar" then
        search_func = Path.astar
    elseif algorithm == "dijkstra" then
        search_func = Path.dijkstra
    elseif algorithm == "bfs" then
        search_func = Path.bfs
    elseif algorithm == "dfs" then
        search_func = Path.dfs
    else
        error("Unsupported algorithm: " .. algorithm)
    end

    -- 执行搜索并返回结果
    local path = search_func(mesh, start_node, end_node)
    if path then
        table.insert(path, end_point)
    end
    return search_func(mesh, start_node, end_node)
end

return Path
