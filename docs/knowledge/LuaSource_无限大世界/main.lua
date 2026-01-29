local UINodes = require("Data.UINodes")

-- 游戏开始事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	local usedTiles = {}
	local freeTiles = { tile1 = {}, tile2 = {} } -- 分开存储两种类型的地块
	local tileUnit1 = LuaAPI.query_unit("地块1")
	local tileUnit2 = LuaAPI.query_unit("地块2")
	
	local tilePrefabId1 = tileUnit1.get_key()
	local tilePrefabId2 = tileUnit2.get_key()
	
	local groundSize = math.Vector3(4, 1, 4)

	-- 定义加载和卸载半径
	local LOAD_RADIUS = 1 -- 加载周围1格地块(3x3)
	local UNLOAD_RADIUS = 3 -- 只有超出3格距离才卸载(7x7)

	local function getKey(x, z)
		return (math.tointeger(x) + 4096) * 65536 + math.tointeger(z) + 4096
	end

	-- 初始两个地块
	usedTiles[getKey(0, 0)] = tileUnit1
	usedTiles[getKey(4, 0)] = tileUnit2

	-- 根据玩家位置更新地块
	local function updateTiles()
		local allRoles = GameAPI.get_all_valid_roles()
		local inLoadRangeTiles = {} -- 加载范围内的地块
		local inUnloadRangeTiles = {} -- 卸载范围内的地块

		for _, role in ipairs(allRoles) do
			local character = role.get_ctrl_unit()
			local position = character.get_position()
			role.set_label_text(UINodes["位置"],
				string.format("当前位置: (%d, %d, %d)", math.tointeger(position.x), math.tointeger(position.y),
					math.tointeger(position.z)))

			-- 计算一下当前地块格子的坐标
			local divisorZ = 1.0 / math.toreal(groundSize.z)
			local z = math.tointeger(math.floor((position.z + groundSize.z * 0.5) * divisorZ))
			local divisorX = 1.0 / math.toreal(groundSize.x)
			local x = math.tointeger(math.floor((position.x + groundSize.x * 0.5) * divisorX))

			-- 记录加载范围内的地块
			for i = x - LOAD_RADIUS, x + LOAD_RADIUS do
				for j = z - LOAD_RADIUS, z + LOAD_RADIUS do
					local posX = i * groundSize.x
					local posZ = j * groundSize.z
					local gridKey = getKey(posX, posZ)
					inLoadRangeTiles[gridKey] = true
				end
			end

			-- 记录卸载范围内的地块
			for i = x - UNLOAD_RADIUS, x + UNLOAD_RADIUS do
				for j = z - UNLOAD_RADIUS, z + UNLOAD_RADIUS do
					local posX = i * groundSize.x
					local posZ = j * groundSize.z
					local gridKey = getKey(posX, posZ)
					inUnloadRangeTiles[gridKey] = true
				end
			end
		end

		-- 加载新的地块
		for gridKey in pairs(inLoadRangeTiles) do
			if not usedTiles[gridKey] then
				local posX = math.floor(gridKey / 65536) - 4096
				local posZ = gridKey % 65536 - 4096

				-- 棋盘格判断：根据格子坐标和决定使用哪种地块
				local gridX = math.floor(posX / groundSize.x)
				local gridZ = math.floor(posZ / groundSize.z)
				local isType1 = (gridX + gridZ) % 2 == 0

				local freeList, prefabId, model
				if isType1 then
					freeList = freeTiles.tile1
					prefabId = tilePrefabId1
					model = tileUnit1
				else
					freeList = freeTiles.tile2
					prefabId = tilePrefabId2
					model = tileUnit2
				end

				local unit = table.remove(freeList)
				if unit then
					unit.set_position(math.Vector3(posX, 0.0, posZ))
					unit.set_model_visible(true)
					unit.set_physics_active(true)
				else
					unit = GameAPI.create_obstacle(prefabId, math.Vector3(posX, 0.0, posZ),
						math.Quaternion(0, 0, 0), model.get_scale())
				end
				usedTiles[gridKey] = unit
			end
		end

		-- 移除超出卸载范围的地块
		for gridKey, unit in pairs(usedTiles) do
			if not inUnloadRangeTiles[gridKey] then
				unit.set_model_visible(false)
				unit.set_physics_active(false)

				-- 判断是哪种类型的地块并放入对应的回收池
				local unitId = unit.get_key()
				if unitId == tilePrefabId1 then
					table.insert(freeTiles.tile1, unit)
				else
					table.insert(freeTiles.tile2, unit)
				end

				usedTiles[gridKey] = nil
			end
		end
	end

	local function onPreTick(_)
		updateTiles()
	end

	LuaAPI.set_tick_handler(onPreTick, nil)
end)
