-- 动画系统 - 处理游戏中的视觉动画效果
-- 包括骰子动画、移动动画等

local State = require("spoke.state")

local AnimationSystem = {}

-- 创建动画状态
function AnimationSystem.createAnimationState()
    return {
        -- 骰子动画
        diceRolling = State.Create(false),
        diceValue = State.Create(1),
        diceAnimationTime = State.Create(0),
        diceAnimationDuration = 0.8,  -- 骰子动画持续时间（秒）
        
        -- 玩家移动动画
        playerMoving = State.Create(false),
        playerMoveProgress = State.Create(0),
        playerMoveFrom = State.Create(1),
        playerMoveTo = State.Create(1),
        
        -- 通用动画计时器
        animationTime = State.Create(0),
    }
end

-- 开始骰子动画
function AnimationSystem.startDiceAnimation(animState, finalValue)
    animState.diceRolling:Set(true)
    animState.diceValue:Set(finalValue or math.random(1, 6))
    animState.diceAnimationTime:Set(0)
end

-- 停止骰子动画
function AnimationSystem.stopDiceAnimation(animState, finalValue)
    animState.diceRolling:Set(false)
    if finalValue then
        animState.diceValue:Set(finalValue)
    end
end

-- 更新骰子动画
function AnimationSystem.updateDiceAnimation(animState, dt, finalValue)
    if not animState or not animState.diceRolling or not animState.diceRolling.Get then
        return false
    end
    
    if not animState.diceRolling:Get() then
        return false
    end
    
    if not animState.diceAnimationTime or not animState.diceAnimationTime.Get then
        return false
    end
    
    local currentTime = animState.diceAnimationTime:Get()
    currentTime = currentTime + dt
    animState.diceAnimationTime:Set(currentTime)
    
    -- 在动画期间随机变化显示值
    if currentTime < animState.diceAnimationDuration then
        -- 更快的翻滚效果
        if math.random() < 0.3 and animState.diceValue then
            animState.diceValue:Set(math.random(1, 6))
        end
        return true
    else
        -- 动画结束，显示最终值
        AnimationSystem.stopDiceAnimation(animState, finalValue)
        return false
    end
end

-- 开始玩家移动动画
function AnimationSystem.startPlayerMoveAnimation(animState, fromPos, toPos)
    animState.playerMoving:Set(true)
    animState.playerMoveProgress:Set(0)
    animState.playerMoveFrom:Set(fromPos)
    animState.playerMoveTo:Set(toPos)
end

-- 更新玩家移动动画
function AnimationSystem.updatePlayerMoveAnimation(animState, dt)
    if not animState or not animState.playerMoving or not animState.playerMoving.Get then
        return false
    end
    
    if not animState.playerMoving:Get() then
        return false
    end
    
    if not animState.playerMoveProgress or not animState.playerMoveProgress.Get then
        return false
    end
    
    local progress = animState.playerMoveProgress:Get()
    progress = progress + dt * 2  -- 移动速度
    
    if progress >= 1 then
        animState.playerMoving:Set(false)
        animState.playerMoveProgress:Set(1)
        return false
    else
        animState.playerMoveProgress:Set(progress)
        return true
    end
end

-- 更新所有动画
function AnimationSystem.updateAll(animState, dt, diceValue)
    if not animState then
        return
    end
    
    -- 更新动画时间
    if animState.animationTime and animState.animationTime.Get then
        local animTime = animState.animationTime:Get()
        animState.animationTime:Set(animTime + dt)
    end
    
    -- 更新骰子动画
    AnimationSystem.updateDiceAnimation(animState, dt, diceValue)
    
    -- 更新玩家移动动画
    AnimationSystem.updatePlayerMoveAnimation(animState, dt)
end

return AnimationSystem
