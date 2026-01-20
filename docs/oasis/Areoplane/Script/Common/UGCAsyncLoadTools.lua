UGCAsyncLoadTools = UGCAsyncLoadTools or {}

function UGCAsyncLoadTools:LoadObject(SourcePath, CallBack)
    if UGCGameSystem.GameState == nil or UE.IsValid(UGCGameSystem.GameState) == false then
        return
    end

    if CallBack == nil then
        return
    end

    if type(CallBack) ~= "function" then
        return
    end

    if UGCGameSystem.GameState.AsyncDelegate == nil then
        UGCGameSystem.GameState.AsyncDelegate = {}
        UGCGameSystem.GameState.AsyncDelegateIndex = 0
    end

    local softObjPath = KismetSystemLibrary.MakeSoftObjectPath(SourcePath)

    UGCGameSystem.GameState.AsyncDelegateIndex = UGCGameSystem.GameState.AsyncDelegateIndex + 1
    local AsyncDelegateIndex = UGCGameSystem.GameState.AsyncDelegateIndex 
    UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex] = ObjectExtend.CreateDelegate(UGCGameSystem.GameState, 
        function (Asset)

            if UGCGameSystem.GameState == nil or UE.IsValid(UGCGameSystem.GameState) == false then
                return
            end

            if Asset == nil then
                print("UGCAsyncLoadTools:LoadObject Error:"..SourcePath)

                if UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex] then
                    ObjectExtend.DestroyDelegate(UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex])
                    UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex] = nil
                end

                return
            end

            CallBack(Asset)
        
            if UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex] then
                ObjectExtend.DestroyDelegate(UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex])
                UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex] = nil
            end
        end
    )

    STExtraBlueprintFunctionLibrary.GetAssetByAssetReferenceAsync(softObjPath, UGCGameSystem.GameState.AsyncDelegate[AsyncDelegateIndex], true)
end

return UGCAsyncLoadTools