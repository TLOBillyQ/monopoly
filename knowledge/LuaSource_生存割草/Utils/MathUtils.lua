local MathUtils = {}

function MathUtils.randint(min, max)
	return min + math.tointeger(LuaAPI.rand() * (max - min))
end

function MathUtils.randCirclePoint(center, minRange, maxRange)
	local radian = LuaAPI.rand() * math.pi * 2
	local distance = minRange + math.sqrt(LuaAPI.rand()) * (maxRange - minRange)
	local offset = math.Vector3(math.cos(radian) * distance, 2, math.sin(radian) * distance)
	return center + offset
end

function MathUtils.randRectanglePoint(center, minOffset, maxOffset)
	local x = minOffset.x + LuaAPI.rand() * (maxOffset.x - minOffset.x)
	local y = minOffset.y + LuaAPI.rand() * (maxOffset.y - minOffset.y)
	local z = minOffset.z + LuaAPI.rand() * (maxOffset.z - minOffset.z)
	return center + math.Vector3(x, y, z)
end

function MathUtils.randomChoice(items)
	return items[MathUtils.randint(1, #items)]
end

function MathUtils.weightedRandomChoice(items, weights)
	-- 计算权重总和
	local totalWeight = 0
	for _, weight in ipairs(weights) do
		totalWeight = totalWeight + weight
	end

	-- 生成随机数
	local randomValue = LuaAPI.rand() * totalWeight

	-- 选择项目
	local currentWeight = 0
	for i, item in ipairs(items) do
		currentWeight = currentWeight + weights[i]
		if randomValue <= currentWeight then
			return i, item
		end
	end
	-- 理论上不会到达这里
	return #items, items[#items]
end

return MathUtils
