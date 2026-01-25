local DebugUtils = {}

function DebugUtils.dump_args(title, ...)
	local args = {...}
	print(string.format("------%s begin: %d ------", title, #args))
	for index, value in ipairs(args) do
		if type(value) == "table" then
			print(string.format("%d.", index))
			for k, v in pairs(value) do
				print("\t", k, v)
			end
		else
			print(string.format("%d.", index), value)
		end
	end
	print(string.format("------%s end ------", title))
end

return DebugUtils