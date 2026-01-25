
local data = {
	passport = {
		name = "通行证",
		passport = true,
	},
	loveGold = {
		name = "爱心金币",
	},
}

local goods = {}
for k, v in ipairs(GameAPI.get_goods_list()) do
	goods[v.name] = v
end

for k, v in pairs(data) do
	if goods[v.name] then
		local good = goods[v.name]
		v.goodsId = good.goods_id
		v.commodityId = good.commodity_infos[1][1]
	else
		data[k] = nil
	end
end

return data
