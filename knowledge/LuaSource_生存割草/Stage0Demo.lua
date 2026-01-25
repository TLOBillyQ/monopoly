local UINodes = require("Data.UINodes")

local Stage0Demo = {}

local function safe_call(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		GlobalAPI.warning("[Stage0Demo] " .. label .. " failed: " .. tostring(err))
	end
	return ok, err
end

local function log_info(msg)
	LuaAPI.log("[Stage0Demo] " .. msg)
end

---阶段0能力确认示例：日志 / UI节点 / UI事件 / 存档 / 音效。
---注意：为了不干扰官方模板逻辑，本模块默认只注册独立事件与计时器，不接管 tick handler。
function Stage0Demo.install(opts)
	opts = opts or {}
	local custom_event_name = opts.custom_event_name or "stage0_demo"
	local archive_key = opts.archive_key or 10001
	local demo_sfx_key = opts.demo_sfx_key or 0

	LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
		log_info("GAME_INIT")

		-- 1) 角色列表
		local roles = GameAPI.get_all_valid_roles() or {}
		log_info("valid roles=" .. tostring(#roles))

		-- 2) 存档读写（每个玩家各自存档）
		for _, role in ipairs(roles) do
			safe_call("archive", function()
				local old = role.get_archive_by_type(Enums.ArchiveType.Int, archive_key)
				local new_val = (tonumber(old) or 0) + 1
				role.set_archive_by_type(Enums.ArchiveType.Int, archive_key, new_val)
				log_info("archive " .. tostring(archive_key) .. "=" .. tostring(new_val) .. " role=" .. tostring(role.get_roleid()))
			end)
		end

		-- 3) UI节点查询
		safe_call("query_ui_node", function()
			local node = LuaAPI.query_ui_node("通用")
			log_info("query_ui_node('通用')=" .. tostring(node))
		end)

		safe_call("query_ui_nodes", function()
			local nodes = LuaAPI.query_ui_nodes({ "通用", "倒计时", "复活按钮" })
			log_info("query_ui_nodes size=" .. tostring(nodes and #nodes or 0))
		end)

		-- 4) UI节点属性（用模板自带 UINodes，不依赖 UI 树命名是否可查）
		for _, role in ipairs(roles) do
			local label = UINodes["倒计时"]
			local button = UINodes["复活按钮"]

			safe_call("ui_props", function()
				role.set_node_visible(label, true)
				role.set_ui_opacity(label, 1.0)
				role.set_label_text(label, "Stage0: READY")
				role.set_label_color(label, 0xFFFFFFFF, 0.0)
				role.set_node_touch_enabled(button, true)
				role.set_button_text(button, "Stage0")
				role.show_tips("Stage0 demo installed", 2.0)
			end)
		end

		-- 5) UI 自定义事件（需在编辑器 UI 侧配置触发该 event_name）
		LuaAPI.global_register_trigger_event({ EVENT.UI_CUSTOM_EVENT, custom_event_name }, function(event_name, actor, data)
			log_info("UI_CUSTOM_EVENT name=" .. tostring(custom_event_name) .. " role_id=" .. tostring(data.role_id) .. " node=" .. tostring(data.eui_node_id))
		end)

		-- 6) 定时器（不依赖 tick handler）
		local counter = 0
		LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1.0 }, function()
			counter = counter + 1
			for _, role in ipairs(roles) do
				local label = UINodes["倒计时"]
				safe_call("timer_ui", function()
					role.set_label_text(label, "Stage0: " .. tostring(counter) .. "s")
				end)
			end
		end)

		-- 7) 音效/声音（key 依赖资源；这里用 pcall 防止无资源时报错）
		safe_call("play_sfx_by_key", function()
			GameAPI.play_sfx_by_key(demo_sfx_key, math.Vector3(0.0, 0.0, 0.0), math.Quaternion(0.0, 0.0, 0.0), 1.0, 1.0, 1.0, true)
		end)
	end)
end

return Stage0Demo
