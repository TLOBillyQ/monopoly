return {
    type = BT.NodeType.SEQUENCE,
    name = "小丑AI",
    children = {
        {
            type = BT.NodeType.ACTION,
            name = "寻找最近玩家",
            func = require "Manager.EntityManager.CommonBehavior.Action.find_nearest_role"
        },
        {
            type = BT.NodeType.FALLBACK,
            name = "选择节点",
            children = {
                {
                    type = BT.NodeType.SUBTREE_REF,
                    name = "攻击玩家",
                    subtree_name = "攻击玩家"
                },
                {
                    type = BT.NodeType.SUBTREE_REF,
                    name = "寻路到玩家",
                    subtree_name = "寻路到玩家"
                }
            }
        }
    },
    subtrees = {
        ["攻击玩家"] =         {
            type = BT.NodeType.SEQUENCE,
            name = "尝试攻击",
            children = {
                {
                    type = BT.NodeType.CONDITION,
                    name = "是否在攻击范围",
                    func = require "Manager.EntityManager.CommonBehavior.Condition.range_less_than",
                    params = {
                        ["threshold"] = 3.0
                    }
                },
                {
                    type = BT.NodeType.EVENT_LISTEN,
                    name = "进入普攻范围",
                    event_name = "进入小丑普攻范围",
                    children = {
                        {
                            type = BT.NodeType.SEQUENCE,
                            name = "尝试普攻",
                            children = {
                                {
                                    type = BT.NodeType.CONDITION,
                                    name = "可普攻",
                                    func = require "Manager.EntityManager.Monster.VengefulClown.Behavior.Condition.could_draw_a_knife"
                                },
                                {
                                    type = BT.NodeType.ACTION,
                                    name = "普攻玩家",
                                    func = require "Manager.EntityManager.Monster.VengefulClown.Behavior.Action.draw_a_knife"
                                }
                            }
                        }
                    }
                },
                {
                    type = BT.NodeType.EVENT_LISTEN,
                    name = "进入开车范围",
                    event_name = "进入小丑开车范围",
                    children = {
                        {
                            type = BT.NodeType.SEQUENCE,
                            name = "尝试开车攻击",
                            children = {
                                {
                                    type = BT.NodeType.CONDITION,
                                    name = "可开车",
                                    func = require "Manager.EntityManager.Monster.VengefulClown.Behavior.Condition.could_drive"
                                },
                                {
                                    type = BT.NodeType.ACTION,
                                    name = "寻路到目标点",
                                    func = require "Manager.EntityManager.CommonBehavior.Action.find_path"
                                },
                                {
                                    type = BT.NodeType.ACTION,
                                    name = "开车到玩家",
                                    func = require "Manager.EntityManager.Monster.VengefulClown.Behavior.Action.drive_to_role"
                                }
                            }
                        }
                    }
                }
            }
        },
        ["寻路到玩家"] =         {
            type = BT.NodeType.TIMEOUT,
            name = "35秒内",
            timeout_duration = 35,
            children = {
                {
                    type = BT.NodeType.SEQUENCE,
                    name = "尝试延路径移动",
                    children = {
                        {
                            type = BT.NodeType.EVENT_LISTEN,
                            name = "重新生成路径",
                            event_name = "重新生成路径",
                            children = {
                                {
                                    type = BT.NodeType.FALLBACK,
                                    name = "尝试生成路径",
                                    children = {
                                        {
                                            type = BT.NodeType.CONDITION,
                                            name = "路径存在",
                                            func = require "Manager.EntityManager.CommonBehavior.Condition.path_exist"
                                        },
                                        {
                                            type = BT.NodeType.ACTION,
                                            name = "寻路到目标点",
                                            func = require "Manager.EntityManager.CommonBehavior.Action.find_path"
                                        }
                                    }
                                }
                            }
                        },
                        {
                            type = BT.NodeType.EVENT_LISTEN,
                            name = "重新开始移动",
                            event_name = "小丑重新开始移动",
                            children = {
                                {
                                    type = BT.NodeType.CONDITION_INTERRUPT,
                                    name = "目标与原定目标点过远",
                                    func = require "Manager.EntityManager.CommonBehavior.Condition.target_too_far",
                                    children = {
                                        {
                                            type = BT.NodeType.ACTION,
                                            name = "沿路径移动到目标",
                                            func = require "Manager.EntityManager.CommonBehavior.Action.move_along_path"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}