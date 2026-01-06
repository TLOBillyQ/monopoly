-- 输入系统 - Spoke框架实现
-- 处理玩家输入和UI交互

local State = require("Spoke.State")
local Trigger = require("Spoke.Trigger")

local InputSystem = {}

-- 创建输入状态
function InputSystem.createInputState()
    return {
        lastKey = State.Create(nil),
        mouseX = State.Create(0),
        mouseY = State.Create(0),
        mouseDown = State.Create(false),
        selectedOption = State.Create(nil),
        
        -- UI状态
        showMenu = State.Create(false),
        showDialog = State.Create(false),
        dialogTitle = State.Create(""),
        dialogMessage = State.Create(""),
        dialogOptions = State.Create({}),
        
        -- 触发器
        onKeyPressed = Trigger.Create("onKeyPressed"),
        onMouseClicked = Trigger.Create("onMouseClicked"),
        onOptionSelected = Trigger.Create("onOptionSelected"),
    }
end

-- 处理按键输入
function InputSystem.handleKeyPress(key, inputState, gameFlow, players)
    inputState.lastKey:Set(key)
    inputState.onKeyPressed:Fire({key = key})
    
    if key == "space" then
        -- 推进游戏阶段
        gameFlow.currentPhase:Set(gameFlow.currentPhase:Get() .. "_next")
        
    elseif key == "a" then
        -- 切换自动模式
        local autoMode = gameFlow.autoMode:Get()
        gameFlow.autoMode:Set(not autoMode)
        
    elseif key == "h" then
        -- 显示帮助
        inputState.showDialog:Set(true)
        inputState.dialogTitle:Set("帮助")
        inputState.dialogMessage:Set("SPACE: 推进 | A: 自动 | ESC: 退出")
        
    elseif key == "escape" then
        love.event.quit()
        
    elseif key == "d" then
        -- 切换调试模式
        
    end
end

-- 处理鼠标点击
function InputSystem.handleMouseClick(x, y, button, inputState)
    inputState.mouseX:Set(x)
    inputState.mouseY:Set(y)
    inputState.mouseDown:Set(true)
    inputState.onMouseClicked:Fire({x = x, y = y, button = button})
    
    -- 检查点击的UI元素
end

-- 处理对话框选项
function InputSystem.handleDialogOption(optionIndex, inputState, gameFlow)
    inputState.selectedOption:Set(optionIndex)
    inputState.onOptionSelected:Fire({optionIndex = optionIndex})
    inputState.showDialog:Set(false)
end

-- 显示对话框
function InputSystem.showDialog(inputState, title, message, options)
    inputState.showDialog:Set(true)
    inputState.dialogTitle:Set(title)
    inputState.dialogMessage:Set(message)
    inputState.dialogOptions:Set(options or {})
end

-- 隐藏对话框
function InputSystem.hideDialog(inputState)
    inputState.showDialog:Set(false)
end

-- 提示购买地块
function InputSystem.promptBuyProperty(inputState, tileName, price)
    InputSystem.showDialog(inputState, "购买地块", 
        string.format("是否购买 %s，价格 %d 金币？", tileName, price),
        {"购买", "不购买"}
    )
end

-- 提示使用物品
function InputSystem.promptUseItem(inputState, itemName)
    InputSystem.showDialog(inputState, "使用物品",
        string.format("是否使用 %s？", itemName),
        {"使用", "保留"}
    )
end

return InputSystem
