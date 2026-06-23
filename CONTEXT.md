# Monopoly Game

This context defines the shared game language for the Eggy Monopoly project. It keeps UI labels and turn-flow terms aligned with player-facing game semantics.

## Language

**可选行动阶段**:
当前玩家可以选择是否继续使用可用道具或其他可选效果的阶段。玩家完成该阶段后，回合继续进入后续必经流程。
_Avoid_: 行动, 任意操作阶段

**行动按钮**:
当前玩家从回合开始的行动等待进入必经回合流程的按钮。它不用于完成可选行动阶段；当结束按钮可用时，行动按钮不应同时作为可点击的推进入口。
_Avoid_: 继续按钮, 泛用推进按钮

**结束按钮**:
当前玩家在可选行动阶段表示不再继续使用可选行动、让回合流程继续的按钮。它固定显示为“结束”，只面向当前玩家，不显示给非当前玩家；可选行动阶段一开始即可点击，不需要二次确认。它不是强制结束整个回合，也不跳过掷骰、移动、落地或回合收尾；倒计时到期等价于结束按钮；它不用于扣留、空可选阶段、托管行动、弹层活动或动画等待。
_Avoid_: 结束回合按钮, 跳过回合按钮, 完成按钮, 跳过按钮, 返回按钮
