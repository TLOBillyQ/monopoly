require "Library.ClassUtils"


---@class NavMesh
---@field is_rendering boolean 是否正在渲染
---@field build_mesh NavMesh.Mesh? 已构建的网格
local NavMesh = {}

NavMesh.start_edit = function()
    LuaAPI.enable_developer_mode()
    local Editor = require "Library.NavMesh.Editor"
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        if NavMesh.build_mesh then
            editor.mesh = NavMesh.build_mesh
        end
        editor:start_edit()
    end
end

NavMesh.stop_edit = function()
    local Editor = require "Library.NavMesh.Editor"
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        if NavMesh.build_mesh then
            editor.mesh = NavMesh.build_mesh
        end
        editor:stop_edit()
    end
end

NavMesh.render = function()
    local Editor = require "Library.NavMesh.Editor"
    NavMesh.is_rendering = true
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        if NavMesh.build_mesh then
            editor.mesh = NavMesh.build_mesh
        end
        editor:render()
    end
end

---@enum NavMesh.Operation
NavMesh.Operation = {
    PLACE = 1,
    REMOVE = 2,
    RESELECT = 3,
}

---@param operation NavMesh.Operation 操作
NavMesh.set_operation = function(operation)
    local Editor = require "Library.NavMesh.Editor"
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        if NavMesh.build_mesh then
            editor.mesh = NavMesh.build_mesh
        end
        editor:set_operation(operation)
    end
end

NavMesh.disable_render = function()
    NavMesh.is_rendering = false
    local Editor = require "Library.NavMesh.Editor"
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        if NavMesh.build_mesh then
            editor.mesh = NavMesh.build_mesh
        end
        editor:disable_render()
    end
end

NavMesh.export = function()
    local Editor = require "Library.NavMesh.Editor"
    for _, role in ipairs(ALLROLES) do
        local editor = Editor.find(role)
        if not editor then
            editor = Editor:new(role)
        end
        editor:export()
    end
end

---@alias NavMeshBuilderConfig {nodes: {[1]: Fixed, [2]: Fixed, [3]: Fixed}[], edges: table<integer, integer[]>}
---@param config NavMeshBuilderConfig
NavMesh.build = function(config)
    NavMesh.disable_render()
    local Builder = require "Library.NavMesh.Builder"
    NavMesh.build_mesh = Builder:new(config).mesh
    return NavMesh.build_mesh
end

NavMesh.is_rendering = true

return NavMesh
