GlobaTickTools = GlobaTickTools or {}

GlobaTickTools.Functions = {}

function GlobaTickTools:RegFuntion(table, func)
    if GlobaTickTools.Functions[table] ~= nil then
        return
    end

    if type(func) ~= "function" then
        return
    end

    GlobaTickTools.Functions[table] = func
end

function GlobaTickTools:UnRegFuntion(table)
    if GlobaTickTools.Functions ~= nil then
        GlobaTickTools.Functions[table] = nil
    end
end

function GlobaTickTools:ReceiveTick(DeltaTime)
    for table,func in pairs(self.Functions) do
        func(table, DeltaTime)
    end
end

return GlobaTickTools