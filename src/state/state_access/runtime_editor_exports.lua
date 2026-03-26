local runtime_constants = require("src.config.gameplay.runtime_constants")
local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")

local runtime_editor_exports = {}
local game_api_key = "Game" .. "API"

local function _resolve_game_api(ctx)
    local env = ctx and ctx.env or nil
    return env and env[game_api_key] or nil
end

local function _resolve_synthetic_camera_target(ctx, role_id)
    local registry = ctx and ctx.synthetic_actor_registry or nil
    if not (registry and type(registry.resolve_actor) == "function") then
        return nil
    end
    local actor = registry.resolve_actor(role_id)
    if actor == nil then
        return nil
    end
    return actor.unit
end

---@return Creature?
local function _resolve_role_camera_target(ctx, role_id)
    local game_api = _resolve_game_api(ctx)
    if not (game_api and game_api.get_role) then
        return nil
    end
    local ok_role, role = pcall(game_api.get_role, role_id)
    if not ok_role or role == nil or type(role.get_ctrl_unit) ~= "function" then
        return nil
    end
    local ok_unit, unit = pcall(role.get_ctrl_unit)
    if not ok_unit then
        return nil
    end
    return unit
end

local function _install_camera_exports(ctx, camera_helper)
    ---@export
    ---@desc 获取相机跟随目标单位
    ---@return Creature
    function get_camera_follow_creature()
        local role_id = number_utils.to_integer(camera_helper.target_role_id)
        if role_id == nil then
            return nil
        end
        local unit = _resolve_synthetic_camera_target(ctx, role_id)
        if unit ~= nil then
            return unit
        end
        return _resolve_role_camera_target(ctx, role_id)
    end
end

local function _install_change_skin_exports(ctx, change_skin_helper)
    ---@export
    ---@desc 获取换肤皮肤ID
    ---@return integer
    function get_skin_id()
        return number_utils.to_integer(change_skin_helper.skin_id) or 0
    end

    ---@export
    ---@desc 获取换肤目标玩家
    ---@return Role?
    function get_change_skin_role()
        local role_id = number_utils.to_integer(change_skin_helper.target_role_id)
        if role_id == nil then
            return nil
        end
        local game_api = _resolve_game_api(ctx)
        if not (game_api and game_api.get_role) then
            return nil
        end
        local ok, role = pcall(game_api.get_role, role_id)
        if not ok then
            return nil
        end
        return role
    end
end

function runtime_editor_exports.install(ctx)
    assert(ctx ~= nil, "missing runtime context")
    assert(ctx.vehicle_helper ~= nil, "missing context.vehicle_helper")
    assert(ctx.camera_helper ~= nil, "missing context.camera_helper")
    assert(ctx.change_skin_helper ~= nil, "missing context.change_skin_helper")
    if not (_G and _G.MONOPOLY_BUILD_MODE == "release") then
        local ok_vehicle_catalog, vehicle_catalog = pcall(require, "src.config.gameplay.vehicle_catalog")
        require("src.state.state_access.vehicle_runtime_source").install_editor_exports(ctx, {
            runtime_constants = runtime_constants,
            logger = logger,
            vehicle_catalog = ok_vehicle_catalog and vehicle_catalog or nil,
            number_utils = number_utils,
        }, _G)
    end
    _install_camera_exports(ctx, ctx.camera_helper)
    _install_change_skin_exports(ctx, ctx.change_skin_helper)
end

return runtime_editor_exports
