local Prefab = require("Data.Prefab")
local Consts = {
	FRAME_PER_SECOND = 30, -- 帧数fps
	SECOND_PER_FRAME = 1.0 / 30, -- 每帧时长
	FPS = 30,

	JOB_CHOOSE_PREFAB = Prefab.group["绑定组 装扮选择区域"], -- 角色选择区域的预设
}

return Consts
