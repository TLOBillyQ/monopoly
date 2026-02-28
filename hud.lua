-- 导入必要的模块
local UINodes = require("Data.UINodes") -- UI节点配置数据
local ArchivesData = require("Data.ArchivesData") -- 存档相关数据
local DesignationData = require("Data.DesignationData") -- 称号配置数据
local GameEvents = require("GameEvents") -- 游戏事件定义
local PrefabData = require("Data.Prefab")

-- 存储所有角色的称号状态信息
-- key: roleId, value: {selDesignationKey, wearDesignationKey, designation3DLayer}
local allRoleStatus = {}

local allCreatureStatus = {}

local designation3DShowLayerDistance = 10

-- 定义系统中所有可用的称号
local DESIGNATION_KEY = {
	"潮流大师",
	"盲盒收藏家",
	"金牌蛋",
}

--- 获取角色称号的存档值
--- @param role table 角色对象
--- @param key string 称号键值或存档键值
--- @return boolean 称号是否已获取或存档值
local function getArchiveValue(role, key)
	local result = role.get_archive_by_type(ArchivesData[key].vType, ArchivesData[key].id)
	return result
end

--- 设置角色称号的存档值
--- @param role table 角色对象
--- @param key string 称号键值或存档键值
--- @param value boolean 要设置的值
local function setArchiveValue(role, key, value)
	role.set_archive_by_type(ArchivesData[key].vType, ArchivesData[key].id, value)
end

--- 根据称号ID获取对应的称号键值
--- @param id number 称号ID
--- @return string|nil 找到则返回称号键值，否则返回nil
local function designationIdToKey(id)
	if not id then
		return nil
	end
	for _, key in ipairs(DESIGNATION_KEY) do
		if DesignationData[key].id == id then
			return key
		end
	end
	return nil
end

--- 为所有角色设置所有称号为已获得状态
local function getAllDesignation()
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		for _, key in ipairs(DESIGNATION_KEY) do
			setArchiveValue(role, key, true)
		end
	end
end

--- 设置称号3D显示层的可见性
--- @param layer number 3D显示层ID
--- @param visible boolean 是否可见
local function setDesignationLayerState(layer, visible)
	if not layer then
		return
	end
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		GameAPI.set_scene_ui_visible(layer, role, visible)
	end
end

--- 更新选中称号的UI显示
--- @param role table 角色对象
--- @param designationKey string 称号键值
local function updateSelDesignationUI(role, designationKey)
	if not role or not designationKey then
		return
	end

	-- 获取称号状态
	local owned = getArchiveValue(role, designationKey)
	local wearDesignationKey = designationIdToKey(getArchiveValue(role, "佩戴称号key"))

	-- 更新称号显示
	local designationInfo = DesignationData[designationKey]
	role.set_label_text(UINodes["选中称号标签文字"], designationInfo.name)
	role.set_image_texture_by_key_with_auto_resize(UINodes["选中称号标签"], designationInfo.icon_id, false)

	-- 更新佩戴按钮状态
	if owned == false then
		role.set_button_text(UINodes["佩戴按钮"], "未获取")
	elseif wearDesignationKey == designationKey then
		role.set_button_text(UINodes["佩戴按钮"], "已佩戴")
	else
		role.set_button_text(UINodes["佩戴按钮"], "佩戴")
	end
end

--- 更新称号的3D显示层
--- @param curRole table 当前角色对象
--- @param designationKey string 称号键值
local function updateDesignationLayer(curRole, designationKey)
	if not curRole or not designationKey then
		return
	end

	-- 获取显示层和称号信息
	local layer = allRoleStatus[curRole.get_roleid()].designation3DLayer
	local owned = getArchiveValue(curRole, designationKey)
	local designationInfo = DesignationData[designationKey]

	-- 获取UI节点
	local iconNode = GameAPI.get_eui_node_at_scene_ui(layer, UINodes["3D称号背景"])
	local nameNode = GameAPI.get_eui_node_at_scene_ui(layer, UINodes["3D称号文字"])

	-- 设置显示状态
	setDesignationLayerState(layer, owned)
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		role.set_image_texture_by_key_with_auto_resize(iconNode, designationInfo.icon_id, false)
		role.set_label_text(nameNode, designationInfo.name)
	end
end

--- 初始化角色的称号UI界面
--- @param role table 角色对象
local function initDesignationUI(role)
	if not role then
		return
	end

	-- 初始化称号列表UI
	for i, key in ipairs(DESIGNATION_KEY) do
		local designationInfo = DesignationData[key]
		-- 设置称号图标
		role.set_image_texture_by_key_with_auto_resize(UINodes["称号标签" .. i], designationInfo.icon_id, false)
		-- 设置称号名称
		role.set_label_text(UINodes["称号标签文字" .. i], designationInfo.name)
		-- 根据获取状态设置显示样式
		local owned = getArchiveValue(role, key)
		if owned == false then
			role.set_label_color(UINodes["称号标签文字" .. i], 0x999999, 0)
		end
	end

	-- 初始化佩戴称号显示
	local roleStatus = allRoleStatus[role.get_roleid()]
	local wearDesignationKey = roleStatus.wearDesignationKey
	local designation3DLayer = roleStatus.designation3DLayer

	-- 处理未佩戴称号的情况
	if wearDesignationKey == nil then
		wearDesignationKey = DESIGNATION_KEY[1]
		setDesignationLayerState(designation3DLayer, false)
	else
		updateDesignationLayer(role, wearDesignationKey)
	end

	-- 更新选中称号UI
	updateSelDesignationUI(role, wearDesignationKey)
end

--- 处理称号佩戴按钮点击事件
--- @param role table 角色对象
--- @param designationKey string 称号键值
local function onClickDesignationWear(role, designationKey)
	if not role or not designationKey then
		return
	end

	local owned = getArchiveValue(role, designationKey)

	-- 处理称号佩戴逻辑
	if owned == false then
		role.show_tips("未获取")
	else
		role.show_tips("已佩戴")
		-- 保存佩戴状态
		setArchiveValue(role, "佩戴称号key", ArchivesData[designationKey].id)
		-- 更新UI显示
		updateSelDesignationUI(role, designationKey)
		updateDesignationLayer(role, designationKey)
	end
end

--- 更新称号显示状态
local function update3DUILayerState()
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		local character = role.get_ctrl_unit()
		local rolePos = character.get_position()
		-- 角色与生物的距离小于10时，显示称号UI
		for unit_id, status in pairs(allCreatureStatus) do
			local creaturePos = GameAPI.get_unit(unit_id).get_position()
			if (rolePos - creaturePos):length() < designation3DShowLayerDistance then
				GameAPI.set_scene_ui_visible(status.designation3DLayer, role, true)
			else
				GameAPI.set_scene_ui_visible(status.designation3DLayer, role, false)
			end
		end
		-- 角色与角色的距离小于10时，显示称号UI
		for _, otherRole in ipairs(GameAPI.get_all_valid_roles()) do
			if role ~= otherRole then
				local otherRolePos = otherRole.get_ctrl_unit().get_position()
				if (rolePos - otherRolePos):length() < designation3DShowLayerDistance then
					local wearDesignationKey = allRoleStatus[otherRole.get_roleid()].wearDesignationKey
					if wearDesignationKey ~= nil then
						GameAPI.set_scene_ui_visible(
							allRoleStatus[otherRole.get_roleid()].designation3DLayer,
							role,
							true
						)
					end
				else
					GameAPI.set_scene_ui_visible(allRoleStatus[otherRole.get_roleid()].designation3DLayer, role, false)
				end
			end
		end
	end
end

-- 注册游戏初始化事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	-- 解锁所有称号
	getAllDesignation()
	-- 为所有的生物添加默认称号UI
	local creatures = GameAPI.get_creatures_in_aabb(math.Vector3(0, 0, 0), 1000.0, 1000.0, 1000.0)
	for _, creature in ipairs(creatures) do
		local designation3DLayer = creature.create_scene_ui_bind_unit(
			PrefabData.layout["3D称号界面"], -- 创建3D显示层
			Enums.ModelSocket.socket_head,
			math.Vector3(0, 3, 0),
			-1.0,
			true,
			true
		)
		allCreatureStatus[creature.unit_id] = { designation3DLayer = designation3DLayer }
		local designationInfo = DesignationData["潮流大师"]
		-- 获取UI节点
		local iconNode = GameAPI.get_eui_node_at_scene_ui(designation3DLayer, UINodes["3D称号背景"])
		local nameNode = GameAPI.get_eui_node_at_scene_ui(designation3DLayer, UINodes["3D称号文字"])
		-- 设置显示状态
		for _, role in ipairs(GameAPI.get_all_valid_roles()) do
			role.set_image_texture_by_key_with_auto_resize(iconNode, designationInfo.icon_id, false)
			role.set_label_text(nameNode, designationInfo.name)
			GameAPI.set_scene_ui_visible(designation3DLayer, role, false)
		end
	end

	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		-- 创建角色状态记录
		allRoleStatus[role.get_roleid()] = {
			selDesignationKey = DESIGNATION_KEY[1], -- 默认选中第一个称号
			wearDesignationKey = designationIdToKey(getArchiveValue(role, "佩戴称号key")), -- 获取已佩戴的称号
			designation3DLayer = role.get_ctrl_unit().create_scene_ui_bind_unit(
				PrefabData.layout["3D称号界面"], -- 创建3D显示层
				Enums.ModelSocket.socket_head,
				math.Vector3(0, 3, 0),
				-1.0,
				true,
				true
			),
		}
		-- 初始化UI显示
		initDesignationUI(role)
	end

	-- 注册称号佩戴按钮点击事件
	LuaAPI.global_register_custom_event(GameEvents.UI_CLICK_DESIGNATION_WEAR, function(_, _, data)
		local roleStatus = allRoleStatus[data.role.get_roleid()]
		local designationKey = roleStatus.selDesignationKey
		roleStatus.wearDesignationKey = designationKey
		onClickDesignationWear(data.role, designationKey)
	end)

	-- 注册称号列表项点击事件
	LuaAPI.global_register_custom_event(GameEvents.UI_CLICK_DESIGNATION_LIST_1, function(_, _, data)
		local designationKey = DESIGNATION_KEY[1]
		allRoleStatus[data.role.get_roleid()].selDesignationKey = designationKey
		updateSelDesignationUI(data.role, designationKey)
	end)

	LuaAPI.global_register_custom_event(GameEvents.UI_CLICK_DESIGNATION_LIST_2, function(_, _, data)
		local designationKey = DESIGNATION_KEY[2]
		allRoleStatus[data.role.get_roleid()].selDesignationKey = designationKey
		updateSelDesignationUI(data.role, designationKey)
	end)

	LuaAPI.global_register_custom_event(GameEvents.UI_CLICK_DESIGNATION_LIST_3, function(_, _, data)
		local designationKey = DESIGNATION_KEY[3]
		allRoleStatus[data.role.get_roleid()].selDesignationKey = designationKey
		updateSelDesignationUI(data.role, designationKey)
	end)

	local function onPreTick()
		update3DUILayerState()
	end
	LuaAPI.set_tick_handler(onPreTick, nil)
end)