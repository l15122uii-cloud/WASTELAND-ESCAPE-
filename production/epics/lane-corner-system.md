# Epic · LaneCornerSystem（三轨系统 + 过弯 + 伪透视投影 + 玩家运动学）

> 对应架构：architecture.md §6（2.5D 伪3D）、§3 LaneSystem/CornerController/PlayerController/Player、core/projection.gd；ADR-001/003。
> 渲染：不使用 Node3D / 真实 3D 相机；纯数学投影（gl_compatibility 友好）。

---

### LCS-1 · 伪透视投影 project(x,z)→(sx,sy,scale)
- 简述：`core/projection.gd` 纯数学：`scale=focal/(z+camNear)`、`screenX=screenCenterX+worldX·scale`、`screenY=horizonY+groundDrop·scale`；参数取自 Tuning（PROJ_*）。
- GDD/ADR 溯源：architecture.md §6.1、ADR-001、Tuning.gd PROJ_*。
- 验收标准（AC）：
  1. `z` 增大 → `scale` 减小（越远越小）；`z=0`（玩家平面）`scale=focal/camNear` 为最大。
  2. `worldX` 线性映射屏幕横向（含车道偏移）；纯数学，无矩阵、无 3D 节点。
  3. 每障碍仅数次乘法，热路径零分配（写已池化节点 position/scale）。
  4. ADR-001 备选正交+线性缩放法可切（Tuning 开关），playtest 校准（CONCERN C7）。
- 规模：M
- 依赖：Tuning.gd
- 切片：⭐ [MVP]

### LCS-2 · LaneSystem 三轨状态 + 平滑插值 + 边界夹取
- 简述：`lane∈{0,1,2}`；`switch_lane(dir)` 改目标并夹取 `[0,2]`；`update(dt)` 用 `laneLerp` 指数平滑 `x` 到 `lane_x(lane)`；`lane_x(lane)=(lane-1)·laneSpacingPx`。
- GDD/ADR 溯源：core-loop.md §2.5/§4（laneWidth/laneLerp）、architecture.md §6.2、ADR-003、Tuning.gd（laneSpacingPx=100）。
- 验收标准（AC）：
  1. 相邻轨切换一次移动一条（`lane±1`，夹紧不越界）。
  2. 横向插值约 0.1–0.15s 到位（`laneLerp=18.0`），不瞬移、不跨轨（core-loop.md §2.5）。
  3. `lane_x(1)=0`（中轨中线），`lane_x(0)/lane_x(2)=∓100px`。
  4. 单测：连续 `switch_lane(-1)` 从 lane2 恰好停 lane0，不溢出（test-plan 切轨用例）。
- 规模：M
- 依赖：Tuning.gd、LCS-1（投影供世界坐标）
- 切片：⭐ [MVP]

### LCS-3 · LaneSystem 锁中轨 + 输入锁（force_center / set_input_locked）
- 简述：CORNER/REVIVE 态 `force_center()` 快速插值回中轨 + `set_input_locked(true)` 屏蔽左右切轨；`JUMP/SLIDE` 仍生效（中轨仍要躲障）。
- GDD/ADR 溯源：core-loop.md §2.6/§3、architecture.md §6.2、ADR-003（横向输入门控）、control-manifest §D2。
- 验收标准（AC）：
  1. `set_input_locked(true)` 时忽略 `LANE_LEFT/RIGHT`，但 `JUMP/SLIDE` 正常（过弯仍能跳/滑）。
  2. `force_center()` 在 `CORNER_ENTER` 触发后插值回 lane1。
  3. `REVIVE`（RESULT）态整体冻结（物理 tick 暂停），横向输入随冻结。
  4. 单测：输入锁期间发 LANE_LEFT 不改 current_lane（test-plan 过弯锁轨用例）。
- 规模：S
- 依赖：LCS-2
- 切片：⭐ [MVP]

### LCS-4 · PlayerController 消费 LaneInput 抽象动作
- 简述：订阅 InputManager 抽象动作 `LANE_LEFT/RIGHT→switch_lane(∓1)`、`JUMP→运动学`、`SLIDE→运动学`；绝不读 `InputEvent` 原始设备（ADR-003）。
- GDD/ADR 溯源：core-loop.md §3、architecture.md §3 PlayerController、ADR-003（输入抽象）。
- 验收标准（AC）：
  1. 仅经 `InputManager` 信号驱动；Player/PlayerController 无任何 `InputEvent` 直接读取（grep 校验）。
  2. 切轨与跳/滑可并行（边切轨边跳）；切轨期间不触发过弯（core-loop.md §2.2）。
  3. 键盘 `A/D/W/S` + 方向键 与触屏手势产出同动作事件（ADR-003 映射表）。
- 规模：M
- 依赖：InputManager（autoload）、LCS-2、SwipeDetector（ADR-003）
- 切片：⭐ [MVP]

### LCS-5 · Player 运动学子状态机（GROUND/JUMP/DOUBLE_JUMP/SLIDE）+ movement.gd
- 简述：子状态机 GROUND_RUN→JUMP(rising/falling)→[DOUBLE_JUMP]→SLIDE；`movement.gd` 重力 g、跳速（矮/高/二段）、滑铲无敌帧；y 随跳跃高度，scale 不变（z=0）。
- GDD/ADR 溯源：core-loop.md §2.2/§4（g/vJumpLow/vJumpHigh/vDblJump/tSlide）、architecture.md §2/§3 Player、ADR-003。
- 验收标准（AC）：
  1. 上滑=矮跳(vJumpLow=11)；按住=高跳(vJumpHigh=17)；空中再上滑=二段跳(vDblJump=13，低于高跳防失控)。
  2. 下滑=滑铲，时长 `tSlide=0.45s`，仅对低障（Overhead）无敌（combo/obstacle 协同）。
  3. 二段跳为同一手势时序组合，无新手势（P1 保证，core-loop.md §3）。
  4. 单测：二段跳后落回 GROUND；滑铲期间 Overhead 不致死（test-plan 跳/二段跳/铲用例）。
- 规模：L
- 依赖：LCS-4、Tuning.gd
- 切片：⭐（跳+二段跳+滑均含）[MVP 跳/滑 · CORE 二段跳]

### LCS-6 · CornerController 过弯（里程碑触发 + yaw 插值 + 锁中轨）
- 简述：CoreLoop 达里程触发 CORNER；`yaw` 从 0 插值到 CORNER_yaw(±90°) 历时 CORNER_duration(1s)；发 CORNER_ENTER（LaneSystem 强制中轨+锁输入）/CORNER_EXIT 解锁；过弯期间世界继续推进（z 递减），仅车道锁定。
- GDD/ADR 溯源：core-loop.md §2.6、architecture.md §6.3、Tuning.gd（CORNER_yaw/duration）、control-manifest §D2。
- 验收标准（AC）：
  1. `maybe_trigger(d)` 按里程进入 CORNER；CorBER 期间 `yaw` 平滑插值、期满归零续跑（伪3D 不跟绝对朝向）。
  2. CORNER_ENTER → LaneSystem.force_center()+set_input_locked(true)；CORNER_EXIT 解锁。
  3. 过弯期间 ObstacleSpawner 仍推进（z 递减），仅中轨生成（OBG-7 协同）。
  4. 单测：进入 CORNER 后 current_lane 收敛到 1（test-plan 过弯锁轨用例）。
- 规模：M
- 依赖：CRL-1（里程触发）、LCS-2/3、ObstacleGeneration(OBG-7)
- 切片：⭐ [CORE 切片段；MVP 切片可含最简弯]

### LCS-7 · TrackView + BackgroundRoot 伪透视道路/车道线/远景自绘
- 简述：`TrackView` 单 CanvasItem 自绘伪透视道路+三车道线（收敛到灭点）；`BackgroundRoot` 天空渐变+远景剪影（≤256px atlas）；二者受 CornerController.yaw 旋转。`set_scroll(speed,yaw)`。
- GDD/ADR 溯源：architecture.md §6.3/§6.4、ADR-001（draw call 预算）、perf-budget §4。
- 验收标准（AC）：
  1. 单屏 draw call ≤50（TrackView 1 call + Background ≤2–3 call + 障碍/玩家 ≤20 → 总 15–30，perf-budget §4.1）。
  2. 道路/车道线随 yaw 旋转模拟转弯；速度感随 V 调 `set_scroll` + 速度线粒子（fx）。
  3. 无实时阴影，仅 BlobShadow（ADR-001）；后处理仅 cheap 暗角/bloom（可关）。
- 规模：L
- 依赖：LCS-1（投影参数）、LCS-6（yaw）
- 切片：部分 ⭐（道路/车道线为切片可见性必需；远景美术在切片可最简）
