---@class NavMesh.Editor
---@field role Role
---@field origin_position Vector3
---@field current_position Vector3
---@field preview_point? SfxID
---@field frameout? Frameout
---@field point_position? Vector3
---@field camera_direction? Vector3
---@field mesh NavMesh.Mesh
---@field last_node? NavMesh.Node
---@field current_placed_nodes NavMesh.Node[]
---@field selected_node? NavMesh.Node
---@field editing boolean
---@field new fun(self: NavMesh.Editor, role: Role): NavMesh.Editor 创建编辑器
local Editor = Class("NavMesh.Editor")
local Mesh = require "Library.NavMesh.Mesh"
local Node = require "Library.NavMesh.Node"
local Utils = require "Library.NavMesh.__init"
Editor.roles = {}

---@param role Role
function Editor:init(role)
    self.role = role
    self.mesh = Mesh:new({ x = 0, z = 0, width = 500, height = 500 })
    self.current_placed_nodes = {}
    self.last_node = nil
    self.editing = false
    Editor.roles[role.get_roleid()] = self
    self:init_controller()
end

---@param role Role
function Editor.find(role)
    return Editor.roles[role.get_roleid()]
end

function Editor:init_controller()
    local char = self.role.get_ctrl_unit()
    UnitTriggerEvent(char, { EVENT.SPEC_LIFEENTITY_MOVE_BEGIN }, function()
        if self.editing then
            if self.role.has_tag("nav_mesh:start_move") then
                return
            end
            self.role.add_tag("nav_mesh:start_move")
        end
    end)

    UnitTriggerEvent(char, { EVENT.SPEC_LIFEENTITY_MOVE_END }, function()
        self:stop_move()
    end)

    UnitTriggerEvent(char, { EVENT.SPEC_LIFEENTITY_JUMP }, function()
        if self.editing then
            self:on_jump()
        end
    end)
end

function Editor:start_edit()
    local char = self.role.get_ctrl_unit()
    self:set_operation(1)
    self.editing = true
    self.origin_position = char.get_position()
    self.current_position = self.origin_position
    self.role.set_camera_lock_position(self.origin_position)
    self.role.set_camera_rotation_sync_enabled(true)
    self.role.set_camera_property(Enums.CameraPropertyType.OBSERVER_HEIGHT, 0.0)
    self.preview_point = GameAPI.play_sfx_by_key(22234, self.current_position, math.Quaternion(0, 0, 0), 0.1, -1.0)
    self.preview_pointB = GameAPI.play_sfx_by_key(22124, self.current_position, math.Quaternion(0, 0, 0), 0.1, -1.0)
    self.preview_highlight = GameAPI.play_sfx_by_key(5833, self.current_position, math.Quaternion(0, 0, 0), 0.2, -1.0)
    GlobalAPI.set_sfx_visible(self.preview_highlight, false)
    self.frameout = SetFrameOut(1, function(frameout)
        self.camera_direction = self.role.get_camera_direction()
        if self.role.has_tag("nav_mesh:start_move") then
            self:start_move()
        end
        GameAPI.raycast_unit(
            self.current_position,
            self.current_position + self.camera_direction * 50,
            { 4, 8, 128, 256, 512, 1024, 32768 },
            function(unit, _collide_point, _normal_vector)
                local position = _collide_point + _normal_vector * 0.15
                local node = nil
                node = self.mesh:query_nearest(position, nil, 1.0)
                if node then
                    position = node.position
                    self.selected_node = node
                    GlobalAPI.set_sfx_visible(self.preview_highlight, true)
                    GlobalAPI.set_sfx_position(self.preview_highlight, position + _normal_vector * 0.15)
                else
                    GlobalAPI.set_sfx_visible(self.preview_highlight, false)
                    self.selected_node = nil
                end
                GlobalAPI.set_sfx_position(self.preview_point, position)
                GlobalAPI.set_sfx_position(self.preview_pointB, position)
                local right = math.Vector3(1, 0, 0)
                if (right - _normal_vector):length() < 0.1 then
                    right = math.Vector3(0, 0, 1)
                end
                local up = _normal_vector:cross(right)
                local pitch = math.atan2(up.y, up.z)
                local yaw = math.atan2(up.x, up.z)
                local rotation = math.Quaternion(pitch, yaw, 0)
                GlobalAPI.set_sfx_orientation(self.preview_point, rotation)
                GlobalAPI.set_sfx_orientation(self.preview_pointB, rotation)
                self.point_position = position + _normal_vector * 0.1
            end
        )
    end, -1, true)
end

local threshold = 0.5
function Editor:start_move()
    local char = self.role.get_ctrl_unit()
    local relative_direction = char.get_linear_velocity()
    local camera_rotation = self.role.get_camera_rotation()
    local v_forward = self.role.get_camera_direction()
    local v_right = camera_rotation:apply(math.Vector3(1, 0, 0))
    local dot_f = relative_direction:dot(v_forward)
    local dot_r = relative_direction:dot(v_right)
    relative_direction:normalize()
    relative_direction.y = self.camera_direction.y
    if math.abs(dot_r) > threshold then
        relative_direction.y = 0
    end

    if dot_f < -threshold then
        relative_direction.y = -relative_direction.y
    end
    self.current_position = self.current_position + relative_direction
    local offset = self.current_position - self.origin_position
    self.role.set_camera_property(Enums.CameraPropertyType.OFFSET_X, offset.x)
    self.role.set_camera_property(Enums.CameraPropertyType.OFFSET_Y, offset.y)
    self.role.set_camera_property(Enums.CameraPropertyType.OFFSET_Z, offset.z)
    char.set_position(self.origin_position)
end

function Editor:stop_edit()
    self.editing = false
    self.role.set_camera_rotation_sync_enabled(false)
    self.role.reset_camera(true, true, true, true)
    if self.frameout then
        self.frameout:destroy()
        self.frameout = nil
    end
    if self.preview_point and self.preview_pointB then
        GlobalAPI.destroy_sfx(self.preview_point)
        GlobalAPI.destroy_sfx(self.preview_pointB)
        self.preview_point = nil
        self.preview_pointB = nil
    end
    self:stop_move()
end

function Editor:stop_move()
    self.role.remove_tag("nav_mesh:start_move")
end

---放置点的策略
---1. 如果当前点与上一个点不相连，则连接两个点
---2. 如果当前点与上一个点相连，则重新选择点
---3. 如果当前点没有选择，则放置一个点
function Editor:place_point()
    local char = self.role.get_ctrl_unit()
    char.set_position(self.origin_position)
    if self.selected_node
        and self.last_node
        and (self.selected_node ~= self.last_node)
        and not self.selected_node:is_connected(self.last_node) then
        ---连接两个点
        self.selected_node:connect(self.last_node)
        self.role.show_tips("成功连接两个点", 2.0)
        self.last_node:render()
        self.last_node = self.selected_node
        self.last_node:render_as_last()
    elseif self.selected_node then
        ---重新选择点
        if self.last_node then
            self.last_node:render()
        end
        self.last_node = self.selected_node
        self.last_node:render_as_last()
        self.role.show_tips("已重新选择新的点", 2.0)
    elseif self.point_position then
        if self.last_node then
            self.last_node:render()
        end
        local node = Node:new(self.point_position)
        node:render()
        self.mesh:insert(node)
        if self.last_node then
            self.last_node:connect(node)
        end
        self.last_node = node
        self.last_node:render_as_last()
        table.insert(self.current_placed_nodes, node)
    end
end

function Editor:remove_point()
    local char = self.role.get_ctrl_unit()
    char.set_position(self.origin_position)
    if self.selected_node then
        self.mesh:remove(self.selected_node)
        self.selected_node = nil
        self.last_node = nil
        self.role.show_tips("已移除一个点", 2.0)
    end
end

function Editor:reselect_point()
    local char = self.role.get_ctrl_unit()
    char.set_position(self.origin_position)
    if self.selected_node then
        if self.last_node then
            self.last_node:render()
        end
        self.last_node = self.selected_node
        self.last_node:render_as_last()
        self.role.show_tips("已重新选择新的点", 2.0)
        self:set_operation(1)
    end
end

---渲染节点
function Editor:render()
    ---@param mesh NavMesh.Mesh
    local function renderNodes(mesh)
        for _, node in ipairs(mesh.nodes) do
            node:render()
        end
        if mesh.northeast then
            renderNodes(mesh.northeast)
        end
        if mesh.southeast then
            renderNodes(mesh.southeast)
        end
        if mesh.southwest then
            renderNodes(mesh.southwest)
        end
        if mesh.northwest then
            renderNodes(mesh.northwest)
        end
    end
    renderNodes(self.mesh)
end

---取消渲染节点
function Editor:disable_render()
    ---@param mesh NavMesh.Mesh
    local function disableRenderNodes(mesh)
        for _, node in ipairs(mesh.nodes) do
            node:disable_render()
        end
        if mesh.northeast then
            disableRenderNodes(mesh.northeast)
        end
        if mesh.southeast then
            disableRenderNodes(mesh.southeast)
        end
        if mesh.southwest then
            disableRenderNodes(mesh.southwest)
        end
        if mesh.northwest then
            disableRenderNodes(mesh.northwest)
        end
    end
    disableRenderNodes(self.mesh)
end

---@param operation NavMesh.Operation
function Editor:set_operation(operation)
    if operation == 1 then
        self.on_jump = self.place_point
        self.role.show_tips("已切换到放置模式", 2.0)
    elseif operation == 2 then
        self.on_jump = self.remove_point
        self.role.show_tips("已切换到移除模式", 2.0)
    elseif operation == 3 then
        self.on_jump = self.reselect_point
        self.role.show_tips("现在可以重新选点", 2.0)
    end
end

---@param mesh NavMesh.Mesh
local function exportMesh(mesh)
    local nodes = {}
    local edges = {}
    local nodeIndexMap = {} -- 用于映射Node对象到索引

    -- 首先收集所有节点并建立索引映射
    local i = 1
    ---@param d_mesh NavMesh.Mesh
    local function collect_nodes(d_mesh)
        for _, node in ipairs(d_mesh.nodes) do
            nodes[i] = { node.position.x, node.position.y, node.position.z }
            nodeIndexMap[node.id] = i
            edges[i] = {} -- 初始化每个节点的边列表
            i = i + 1
        end
        if d_mesh.northeast then
            collect_nodes(d_mesh.northeast)
        end
        if d_mesh.southwest then
            collect_nodes(d_mesh.southwest)
        end
        if d_mesh.northwest then
            collect_nodes(d_mesh.northwest)
        end
        if d_mesh.southeast then
            collect_nodes(d_mesh.southeast)
        end
    end
    collect_nodes(mesh)

    -- 遍历所有节点处理边关系
    for nodeid, currentIndex in pairs(nodeIndexMap) do
        local node = Node.query_node_by_id(nodeid)

        for _, edge in ipairs(node.edges) do
            -- 确定边的另一端节点
            local otherNode = edge:get_to_node(node)
            local otherIndex = nodeIndexMap[otherNode.id]

            -- 只记录索引较小的节点到索引较大的节点的边，避免重复
            if currentIndex < otherIndex then
                table.insert(edges[currentIndex], otherIndex)
            end
        end
    end

    return {
        nodes = nodes,
        edges = edges
    }
end

local function exportMeshToFile(mesh, filename)
    local data = exportMesh(mesh) -- 使用之前定义的exportMesh函数

    -- 打开文件用于写入
    local file = io.open(filename, "w")
    if not file then
        error("无法打开文件: " .. filename)
    end

    -- 写入文件头部
    file:write("return {\n")
    file:write("    nodes = {\n")

    -- 写入节点数据
    for i, node in ipairs(data.nodes) do
        file:write(string.format("        {%f, %f, %f}", node[1], node[2], node[3]))
        if i < #data.nodes then
            file:write(",")
        end
        file:write("\n")
    end

    file:write("    },\n")
    file:write("    edges = {\n")

    -- 写入边数据
    local edgeCount = 0
    for i, connections in ipairs(data.edges) do
        if #connections > 0 then
            edgeCount = edgeCount + 1
            file:write(string.format("        [%d] = {", i))

            for j, target in ipairs(connections) do
                file:write(tostring(target))
                if j < #connections then
                    file:write(", ")
                end
            end

            file:write("}")
            if edgeCount < #data.edges then
                file:write(",")
            end
            file:write("\n")
        end
    end

    file:write("    }\n")
    file:write("}\n")

    -- 关闭文件
    file:close()

    print("成功导出到“蛋仔编辑器”安装目录下的: " .. filename)
end

function Editor:export()
    LuaAPI.enable_developer_mode()
    exportMeshToFile(self.mesh, "mesh_data.lua")
end

return Editor
