UGCEventSystem = UGCEventSystem or 
{
    Events = {};
};

--添加监听
function UGCEventSystem:AddListener(EventType, Func, Object)
    if EventType == nil or Func == nil then
        print("Error: UGCEventSystem:AddListener EventType or Func is nil!");
        return;
    end

    local FuncData = {};
    FuncData.Object = Object;
    FuncData.Func = Func;

    if self.Events[EventType]==nil then
        local NewEventFuncs={};
        table.insert(NewEventFuncs ,FuncData);
        self.Events[EventType] = NewEventFuncs;
        ugcprint(string.format("UGCEventSystem:AddListener EventType[%s], Func[%s]", tostring(EventType), tostring(Func)));
    else
        table.insert(self.Events[EventType], FuncData)
        ugcprint(string.format("UGCEventSystem:AddListener EventType[%s], Func[%s]", tostring(EventType), tostring(Func)));
    end
end

--移除监听
function UGCEventSystem:RemoveListener(EventType, Func, Object)
    if EventType == nil or Func == nil then
        print("Error: UGCEventSystem:AddListener EventType or Func is nil!");
        return;
    end
    local EventFuncs = self.Events[EventType];
    if EventFuncs ~= nil then
        for i, FuncData in pairs(EventFuncs) do
            if FuncData.Func == Func and FuncData.Object == Object then
                EventFuncs[i] = nil;
            end
        end
    end
end

function UGCEventSystem:RemoveAll()
    for k,EventFuncs in pairs(self.Events) do
        for i, FuncData in pairs(EventFuncs) do
            FuncData.Func = nil
            FuncData.Object = nil
        end
    end

    self.Events = {}
end

--派发事件
function UGCEventSystem:SendEvent(EventType, ...)
    ugcprint(string.format("UGCEventSystem:SendEvent self[%s], EventType[%s]", tostring(self), tostring(EventType)));
    if EventType ~= nil then
        local EventFuncs = self.Events[EventType];
        if EventFuncs ~= nil then
            for i, FuncData in pairs(EventFuncs) do
                if FuncData.Object ~= nil then
                    FuncData.Func(FuncData.Object, ...);
                else
                    FuncData.Func(...);
                end
            end
        else
            ugcprint(string.format("UGCEventSystem:SendEvent EventFuncs[%s] is nil!", tostring(EventType)));
        end
    end
end

return UGCEventSystem