--[[------------------------------------------等待玩家加入------------------------------------------------------]]--
local Action_WaitPlayerJoin = 
{
}


function Action_WaitPlayerJoin:Execute()
	print(string.format("Action_WaitPlayerJoin:Execute"));

	self.bEnableActionTick = true;
	return true;
end

function Action_WaitPlayerJoin:Update(deltaTime)
	--print_dev("Action_WaitPlayerJoin:Update");
	
	local PlayerList = UGCGameSystem.GetAllPlayerController()
	local Count = #PlayerList
	if Count > 0 then
		-- 第一个玩家加入之后进入准备阶段
		print(string.format("Action_WaitPlayerJoin:First player join, enter prepare stage"));
		LuaQuickFireEvent("EnterPrepareStage", self); 
		self.bEnableActionTick = false;
	end

end

return Action_WaitPlayerJoin
