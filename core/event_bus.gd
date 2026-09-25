extends Node
## EventBus — 信号总线单例（autoload "EventBus"）。
## 架构红线（control-manifest §B）：模块间唯一解耦通道，禁止跨模块直接字段耦合。
## 抽象动作信号（lane_left/lane_right/jump/slide）由 InputManager 发出、Player 订阅；
## 状态/结果信号由各系统发出供 HUD/Combo/Ad 消费。
## 注：本文件头标注「需 Godot CI 执行」——本环境无 Godot 运行时，仅可评审。

# ── 抽象输入动作（InputManager → Player） ──
signal lane_left()            # 切左轨
signal lane_right()           # 切右轨
signal jump()                 # 跳（矮/高，按住时长映射）
signal slide()                # 滑铲

# ── 状态/结果（各系统 → HUD/Combo/Ad） ──
signal lane_changed(lane)     # 实际切轨完成（lane∈{0,1,2}）
signal double_jump()          # 二段跳发生（连击计分用）
signal hit()                  # 障碍真实碰撞（→ game_over）
signal pickup(kind)           # 拾取 supply/medkit
signal near_miss(kind)        # 近失 graze/flank
signal combo_changed(combo, m)    # 连击/倍率变化
signal score_changed(score)        # 分数变化
signal distance_changed(d)         # 距离变化
signal corner_enter()              # 入弯（锁中轨+锁横向）
signal corner_exit()               # 出弯
signal game_over()                 # 死亡 → RESULT
signal revive_requested(reason)    # 请求激励视频（revive/double/milestone）
signal revive_granted()            # 奖励到账
signal revive_declined()           # 拒绝/无奖励
