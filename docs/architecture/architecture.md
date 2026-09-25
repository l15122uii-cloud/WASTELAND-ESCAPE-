# 技术主架构文档 ·《WASTELAND ESCAPE / 废土逃生》

> 阶段：Phase 3 技术搭建（**三轨背后视角重构**）｜ 评审强度：lean
> 引擎：Godot 4（Web/HTML5 导出，渲染方法 `gl_compatibility` / WebGL2）
> 作者：程基岩（engineering-lead）｜ 依赖：D1–D4、core-loop / obstacle-gen / combo-scoring 三系统 GDD、美术圣经性能红线
> 配套文档：`adr/`（ADR-001~005）、`perf-budget.md`（R4 回签）、`control-manifest.md`（实现前检查）
> **重构要点（本次）**：玩法呈现由「2D 横版 + 2.5D 视差」升级为「**2.5D 伪3D 三轨身后视角**」（类似《神庙逃亡》/《地铁跑酷》）；平台范围扩展为 Web/HTML5 + TapTap + 微信/抖音小程序（H5 容器加载 HTML5 export）。

---

## 0. 范围与工程原则
- **引擎与渲染**：Godot 4.x，Web/HTML5 导出，渲染方法强制 `gl_compatibility`（WebGL2）——这是 Web 平台唯一稳定的渲染后端（Forward+/Mobile 在 Web 不可用）。
- **语言**：GDScript。热路径（每帧 Process/Physics）零分配；对象池复用避免 GC 尖刺。
- **2.5D 伪3D 呈现（本次新增原则）**：赛道为向 **z 纵深**延伸的平面，三轨为 **x 方向三条车道**（lane∈{0,1,2}）；采用**伪透视投影**（手工将世界 `(x,z)` 投影到 2D Sprite 屏幕坐标，**不使用 Node3D**），保持 gl_compatibility/WebGL2 友好与 ≤50 draw call 预算。详见 §6。
  - 坐标真值：世界以 `(x, z)` 描述，玩家固定锚点于相机平面 `z=0`，世界"前进"由障碍 `z` 递减 + 背景/赛道滚动模拟，**不移动玩家节点**。
- **一致性红线（继承自 GDD）**：
  - 速度模型 `V(d,combo)` 唯一真值源只在 `CoreLoop`；障碍间隔、连击衰减均读它，不在三处各写。
  - 近失阈值 `nearMissBand/Tier` 唯一真值源只在 `ObstacleGen`；连击系统引用，不重定义。
  - 三轨参数（`LANE_*`、`PROJECTION_*`）唯一集中处只在 `autoload/Tuning.gd`。
- **解耦原则**：模块间只经 `EventBus`（Autoload 信号总线）通信；**UI/HUD 不持有任何游戏状态**，仅订阅只读快照。
- **Web 约束**：默认单线程（pthreads 需 COOP/COEP 头），重逻辑全部主线程；音频需首次输入 resume；切后台暂停物理 tick。
- **统一变现口径（ADR-005）**：`revive_daily_cap = 3`（**已与策划侧对齐，锁定为 3；可配，按平台政策**）、`revive_per_run_max = 1`；复活仅发生在 RESULT 态并暂停物理 tick。

---

## 1. 项目目录结构
```
res://
├── project.godot                 # 渲染方法=gl_compatibility；视口 1280x720，stretch=viewport/aspect=expand
├── main.gd / Main.tscn           # 引导（BOOT→MENU→RUNNING→RESULT）
├── autoload/                     # 全局单例（在 project.godot 注册）
│   ├── EventBus.gd               # 信号总线：NEAR_MISS / FATAL_HIT / PICKUP / SPAWN / STATE_CHANGED
│   │                             #   + CORNER_ENTER / CORNER_EXIT / LANE_CHANGED
│   ├── Tuning.gd                 # 全部 GDD 数值常量（Vmax, interval*, nearMiss*, PPM, LANE_*, PROJECTION_*, revive caps…）唯一集中处
│   ├── SaveManager.gd            # 最佳记录/里程碑/复活计数读写（localStorage + 内存降级）
│   ├── AdManager.gd              # 可选 Autoload：激励视频/复活；三平台 Provider 调度（core+ 变现档；MVP 可禁用）
│   ├── AdProvider.gd            # 广告供应商抽象接口（has_ad / show_rewarded）
│   ├── providers/               # AdProviderWeb / AdProviderMiniProgram / AdProviderTapTap（详见 §7.4）
│   ├── InputManager.gd           # 触屏滑动+键盘 → 统一 LaneInput 抽象动作（LANE_LEFT/RIGHT/JUMP/SLIDE）
│   └── TapTapSDK.gd              # 可选 module：登录/排行/成就（H5 SDK 桥接）
├── core/
│   ├── CoreLoop.gd               # 顶层状态机 + 每帧推进 d/V/score；拥有速度模型；驱动过弯里程碑
│   ├── SpeedModel.gd             # V(d,combo) 实现（被 CoreLoop 调用）
│   └── projection.gd            # 伪透视投影纯数学：project(worldX, z) -> (screenX, screenY, scale)
├── lane/
│   ├── LaneSystem.gd             # lane∈{0,1,2} + 平滑插值 + 中轨锁定(force_center) + 输入锁
│   └── CornerController.gd       # 过弯视角旋转(yaw) + 中轨锁定触发 + CORNER 状态
├── player/
│   ├── PlayerController.gd       # 三轨输入映射：跳/滑/切轨（消费 LaneInput）
│   ├── Player.gd                 # 子状态机 GROUND/JUMP/SLIDE；x=laneX 插值, y=jump, scale 不变(z=0)
│   ├── Player.tscn
│   └── movement.gd               # 运动学：重力 g、跳速、滑铲无敌帧
├── obstacles/
│   ├── ObstacleSpawner.gd         # 距离种子 RNG 调度；调 ObstaclePool 激活/回收；含 z 纵深
│   ├── ObstaclePool.gd            # 对象池（poolSize=24），free-list 管理；节点每帧经 projection 投影
│   ├── Obstacle.gd               # 基类：AABB（屏幕投影后）、近失最小间隙结算、类型标签
│   ├── obstacles/                # Spike/Barrier/Overhead/Gap/Wall/Moving/Sequence
│   └── PickupPool.gd             # 金币/星 独立池（建议 pickupPoolSize=32）
├── combo/
│   └── ComboScoring.gd           # 连击状态机、m(combo)、tick(dt) 衰减窗口
├── input/
│   └── SwipeDetector.gd          # 上/下/左/右 滑动；最小位移+时长去抖；仅主指（映射 LaneInput）
├── track/
│   ├── TrackView.gd              # 伪透视道路 + 车道线绘制（CanvasItem 自绘；受 CornerController.yaw 旋转）
│   └── BackgroundRoot.gd         # 天空/远景剪影 + 远层视差（过弯可旋转）
├── persistence/                  # （逻辑在 autoload/SaveManager，无独立场景）
├── hud/
│   ├── HUD.gd                    # 距离/分数/连击只读订阅；不持有状态
│   └── HUD.tscn
├── fx/
│   └── ParticlePool.gd           # 粒子池上限 120（落地/速度线/拾取共享）
├── ui/
│   ├── Menu.tscn                 # MENU 态
│   └── Result.tscn               # RESULT 态（一键重开 + 看广告复活按钮）
└── config/tuning.gd              # 见 autoload/Tuning.gd（同一文件）
```

---

## 2. Godot 场景树（主场景 `Main.tscn`，三轨身后视角）
```
Main (Node2D 根)
├── BackgroundRoot (Node2D)        — 天空渐变 + 远景剪影（受 CornerController.yaw 旋转）
├── TrackView (Node2D)             — 伪透视道路/车道线（CanvasItem 自绘，受 yaw 收敛到灭点）
├── World (Node2D)
│   ├── Player (Node2D)            — 固定锚点；x=laneX 插值, y=跳跃高度, scale 不变(z=0)
│   │   └── BlobShadow (Sprite2D)  — 脚下廉价阴影（无实时阴影）
│   ├── ObstacleSpawner (Node2D)
│   ├── ObstaclePoolRoot (Node2D)   — 池化障碍节点；每帧经 projection 投影到屏幕（z→scale/屏幕位置）
│   └── PickupPoolRoot (Node2D)
├── FXRoot (Node2D)                — ParticlePool 节点（速度线/沙尘/拾取）
├── HUD (CanvasLayer)              — 距离/分数/连击
├── Menu (CanvasLayer)             — MENU 态显示
└── Result (CanvasLayer)           — RESULT 态显示

[Autoload 单例，不入树] EventBus · Tuning · SaveManager · AdManager(可选) · InputManager · TapTapSDK(可选)
[纯数学，非节点] core/projection.gd（Projection 相机参数：focal / horizonY / screenCenterX / laneWidth）
```
> 说明：**不**使用 Camera2D 跟随平移；"前进感"由障碍 `z` 递减 + TrackView/BackgroundRoot 滚动模拟。玩家锚点固定在屏幕下方中央偏上，x 仅随车道偏移（laneX 插值），y 随跳跃/滑铲变化。障碍因在 `z>0` 纵深，需每帧经 `projection.project()` 求屏幕坐标与缩放（廉价纯数学，无矩阵无 3D 节点）。

---

## 3. 核心模块划分与职责
| 模块 | 职责 | 关键接口 |
|---|---|---|
| **CoreLoop** | 顶层状态机（BOOT/MENU/RUNNING/CORNER/RESULT）；每帧 `d += V·dt`、`score += V·dt·m`；路由事件；拥有速度模型真值；按里程触发过弯里程碑 | `update(dt)`、`on_event()`、`SpeedModel.V(d,combo)`、`maybe_corner(d)` |
| **LaneSystem** | 三轨状态 `lane∈{0,1,2}`；平滑插值到目标车道 x；`force_center()` 过弯中轨锁定；`set_input_locked()` 锁横向输入 | `current_lane`、`target_lane`、`lane_x(lane)`、`switch_lane(dir)`、`force_center()`、`update(dt)`、`set_input_locked(b)` |
| **CornerController** | 过弯调度（CoreLoop 里程触发）；`yaw` 视角旋转插值；触发中轨锁定 + 发 `CORNER_ENTER/EXIT`；CORNER 态暂停横向输入 | `update(dt)`、`maybe_trigger(d)`、`yaw`、`is_cornering()` |
| **PlayerController** | 三轨输入映射：消费 LaneInput（LANE_LEFT/RIGHT→切轨, JUMP, SLIDE）；驱动 Player 运动学；CORNER/REVIVE 下屏蔽横向输入 | `on_lane(dir)`、`on_jump()`、`on_slide()`、`update(dt)` |
| **ObstacleSpawner + ObstaclePool** | 距离种子 RNG 调度；按 `tier` 门控；含 `z` 纵深；经池激活/回收；结算近失 | `update(dt,V,d,tier)`、`spawn()`、`recycle()`、`project_all()` |
| **ComboScoring** | 连击状态机、倍率 `m(combo)`、衰减窗口 `tick(dt)`；消费 NEAR_MISS/PICKUP/技巧事件 | `on_near_miss(prox)`、`on_pickup(t)`、`tick(dt)`、`m`、`combo` |
| **InputManager + SwipeDetector** | 触屏滑动+键盘 → 统一 LaneInput 抽象动作（LANE_LEFT/RIGHT、JUMP、SLIDE）；去抖；仅主指 | `action_lane(dir)` / `action_jump` / `action_slide` 信号 |
| **SaveManager** | 最佳距离/分数、跨局累计里程碑、复活计数；localStorage 不可用时降级内存 | `load()`、`save_best()`、`add_milestone()`、`record_revive()` |
| **AdManager（+ AdProvider）** | 可选激励视频/复活（core+ 变现档）；**三平台 Provider 调度**（Web/小程序/TapTap）；频率上限与 consent 门控；不参与玩法 | `is_revive_available()`、`request_revive(cb)`、`request_double_reward(cb)` |
| **TrackView + BackgroundRoot** | 伪透视道路/车道线 + 天空/远景（2.5D 纵深卖点）；受 `CornerController.yaw` 旋转 | `set_scroll(speed, yaw)` |
| **HUD** | 只读订阅距离/分数/连击/里程碑；不持有状态 | 订阅 `EventBus` 快照信号 |
| **ParticlePool** | 池化粒子，硬上限 120 | `emit(type, pos)` |

---

## 4. 数据流（三系统咬合，经 EventBus）
```
[ObstacleSpawner] --SPAWN--> 世界实体（池激活，含 z 纵深）
      │                         │
      │ NEAR_MISS(prox) / FATAL_HIT / PICKUP(t)
      ▼                         ▼
[EventBus] ──路由──► [CoreLoop] ──转发──► [ComboScoring] 更新 combo / m
      │                         │                         │
      │ 每帧 CoreLoop: d+=V·dt  │ 每帧 ComboScoring.tick(dt)│ 读 m 供计分/HUD
      ▼                         ▼                         ▼
   HUD(距离/分/连击) ◄── m,combo,score ── 持久化(最佳/里程碑 D4)
```
- `CoreLoop` 每帧把 `(V, d, tier)` 喂给 `ObstacleSpawner.update()`；把 `NEAR_MISS/PICKUP/技巧` 转发 `ComboScoring`。
- `ComboScoring` 每帧 `tick(dt)` 推进衰减；输出 `m` 回 `CoreLoop` 计分与 HUD。
- **三轨输入链**：`SwipeDetector` → `InputManager`（LaneInput）→ `PlayerController` → `LaneSystem.switch_lane()` / `Player` 跳滑。CORNER/REVIVE 态由 `LaneSystem.set_input_locked(true)` 屏蔽横向切轨（详见 §6.2）。
- `FATAL_HIT` → `CoreLoop` 切 RESULT；死亡时 `SaveManager` 落盘。
- **过弯链**：`CoreLoop.maybe_corner(d)` 达里程 → `CornerController` 进 CORNER → 发 `CORNER_ENTER`（LaneSystem 强制中轨 + 锁横向输入）→ `yaw` 旋转 → 发 `CORNER_EXIT` 解锁。过弯期间世界继续推进（障碍 `z` 仍递减），仅车道锁定。
- **广告/复活（可选，core+ 档）**：`CoreLoop` 进 RESULT 经 `EventBus` 通知 `AdManager`；`AdManager` 校验「本局未复活 + 每日上限未达 + consent/广告可用」后向 Result UI 提供「看广告复活」按钮；接受 → `AdManager` 暂停物理 tick → 经**当前平台 Provider** 调广告 SDK → 奖励到账发 `REVIVE_GRANTED` → `CoreLoop` 重置玩家（清附近障碍 + 短暂无敌）回 RUNNING；失败/无奖励维持 RESULT。此链路**不引入任何玩法输入**，P1 支柱不受影响（详见 §8 / ADR-005）。

---

## 5. 对象池策略（防 GC，满足 R4）
- **ObstaclePool**：预实例化 `poolSize=24` 个障碍节点（按类型标签混合或分类子池），挂 `ObstaclePoolRoot`，初始 `visible=false`。
- **激活**：`spawn()` 从 free-list 取节点 → 重置 transform/类型/碰撞/`z` → `visible=true`；**不** `queue_free`。
- **回收**：节点 `z` 越过玩家身后余量 → 还 free-list → `visible=false`。
- **溢出**：live 数达 `maxLiveObstacles=12` 或池空 → **停止生成**直到回收（GDD §5 已定）。
- **拾取物独立池** `PickupPool`（建议 32），不挤占障碍池。
- **投影**：池节点为 2D Sprite，每帧由 `project_all()` 经 `projection.project(laneX, z)` 写屏幕坐标与 `scale`；障碍回收/激活不改变节点数 → 每帧零分配。
- 效果：每帧零节点分配，GC 尖刺 <0.5ms（见 perf-budget §2）。

---

## 6. 2.5D 伪3D 三轨身后视角实现
> 设计目标：神庙逃亡式三轨追尾视角，赛道向 z 纵深延伸，三轨为 x 向车道；**不使用 Node3D/真正的 3D 相机**，以纯数学伪透视投影把 `(x,z)` 映射到 2D Sprite，从而 100% 兼容 gl_compatibility/WebGL2，且不增加 draw call 预算（详见 §6.4）。

### 6.1 坐标与投影（`core/projection.gd`）
- 世界坐标：`x` = 横向（车道），`z` = 纵深（距相机平面的前方距离，`z=0` 即玩家所在平面，`z>0` 为前方）。
- 相机在原点朝 +z，参数集中在 `Tuning.gd`：`focal`（焦距，px）、`horizonY`（灭点屏幕 y）、`screenCenterX`、`laneSpacingPx`（相邻轨中心距 px，= `laneWidthM×PPM` = 100）。
- 投影公式（纯数学，每障碍仅数次乘法）：
  ```
  scale       = focal / (z + camNear)            # z 越大越小
  screenX     = screenCenterX + worldX * scale    # worldX 已含车道偏移
  screenY     = horizonY + groundDrop * scale     # 地面随 z 收敛到灭点
  ```
  - 障碍：`worldX = LaneSystem.lane_x(lane)`，`z` 随时间 `z -= V·dt`（前方→玩家）。
  - 玩家：`z=0`，锚定屏幕下方中央，`x = laneX(currentLane)` 插值，`y` 随跳跃高度上移、`scale` 不变。
- **备选（更廉价）**：正交 + 线性缩放（scale 随 z 线性而非 `1/(z+near)`，并给车道线轻微 x 收敛到灭点）。主推伪透视，但二者皆零 3D 开销，参数均 `Tuning` 可调，留待 playtest 校准（CONCERN C7）。

### 6.2 三轨系统（`lane/LaneSystem.gd` + `player/PlayerController.gd`）
- `LaneSystem` 持有 `current_lane`、`target_lane`（∈{0,1,2}）；`switch_lane(dir)` 改目标并夹取边界；`update(dt)` 用 lerp 平滑 `x` 到 `lane_x(target)`（防瞬移）。
- `PlayerController` 消费 LaneInput：`LANE_LEFT→switch_lane(-1)`、`LANE_RIGHT→switch_lane(+1)`、`JUMP`/`SLIDE` 驱动运动学。
- **输入锁**：`set_input_locked(true)` 时忽略 `LANE_LEFT/RIGHT`，但 `JUMP`/`SLIDE` 仍生效（中轨仍要躲障碍）。`CoreLoop` 在 **CORNER** 与 **REVIVE(RESULT)** 态置锁。

### 6.3 过弯（`lane/CornerController.gd`）
- 触发：`CoreLoop.maybe_corner(d)` 按里程（或 `ObstacleGen` tier 调度）进入 CORNER，发 `CORNER_ENTER`。
- 行为：`LaneSystem.force_center()`（快速插值回中轨 1）+ `set_input_locked(true)`；`CornerController` 把 `yaw` 从 0 插值到目标角（如 ±90°）历时 `cornerDuration`，`TrackView`/`BackgroundRoot` 据此旋转道路/远景以模拟转弯；期满发 `CORNER_EXIT` 解锁（伪3D 不跟踪绝对朝向，yaw 归零续跑）。
- **CORNER 期间世界继续推进**（障碍 `z` 仍递减），仅车道锁定中轨；**REVIVE(RESULT)** 态则整体冻结（物理 tick 暂停）。

### 6.4 纵深卖点与 draw call 预算
- **TrackView** 用单个 `CanvasItem` 自绘伪透视道路 + 三条车道线（收敛到灭点）→ **1 个 draw call**。
- **BackgroundRoot** 天空渐变 + 1–2 张远景 atlas（≤256px）→ ≤2–3 draw call。
- 障碍/拾取：Sprite2D 共享 atlas 材质 → 合批；即便不合批，live 障碍 ≤12 + 玩家 + 阴影 ≈ <20 call。
- **结论：三轨伪透视投影不引入任何额外 draw call 类型**，全屏估算 15–30 call，远优于 ≤50 红线（perf-budget §4 口径不变）。
- 无实时阴影：仅 `BlobShadow`（椭圆 Sprite2D）；后处理仅 cheap 暗角/轻 bloom（可关）。
- 速度感：随 `V` 调 `TrackView.set_scroll()` + 速度线粒子 + 轻微 FOV/zoom lerp。

### 6.5 LaneGeometry 车道几何常量（Tuning.gd 唯一真值）
> 与设计侧 `obstacle-gen.md` §8 近失横向净空公式对齐；常量全部落在 `autoload/Tuning.gd`（已建），架构侧不再另写。

| 常量 | 值 | 含义 / 推导 |
|---|---|---|
| `PPM` | 50 | pixels per meter（世界尺度，perf-budget §1） |
| `laneWidthM` | 2.0 m | 相邻轨中心距（米） |
| `laneSpacingPx` | 100 px | 相邻轨中心距 = `laneWidthM × PPM`（LaneSystem.lane_x 用） |
| `laneWidthPx` | 100 px | 旧名 alias，等价 `laneSpacingPx`（投影/车道宽统一用 `laneSpacingPx`） |
| `playerHalfWidthPx` | 20 px | 玩家碰撞半宽（初值，playtest 校准） |
| `obstacleHalfWidthPx` | 20 px | 障碍碰撞半宽（初值，playtest 校准） |

- **相邻轨掠过横向净空** = `laneSpacingPx − playerHalfWidthPx − obstacleHalfWidthPx` = 100 − 20 − 20 = **60 px**。
- 该净空与 `nearMissBand`(24px) 的"触发阈值 / 间距"关系属 **playtest 校准项**（呼应 design-side CONCERN）：常量先落地使公式可验证；是否让 60px 净空落入 band（或调 band/间距）留 playtest 定，属可调常量，不影响架构与 R4。

---

## 7. Web 导出与平台集成
> 引擎基础约束（保留）：`gl_compatibility` / WebGL2、单线程、音频首次输入 resume、localStorage 持久化、切后台暂停物理 tick。本节在保留 Web 基础上扩展 **TapTap** 与 **微信/抖音小程序** 三套目标平台的导出与集成。

### 7.1 HTML5 export preset（保留并明确）
- **渲染方法**：`rendering/renderer/rendering_method="gl_compatibility"`（**必须**，否则 Web 黑屏/崩溃）。
- **视口/拉伸**：base 1280×720，stretch `mode=viewport`、`aspect=expand`；移动端经 ProjectSettings 或启动参数降 `480p` 兜底（GDD 要求 480p 降级）。
- **线程**：Web 默认单线程；**禁用 `Thread`**；如需并行 AI，后续评估 COOP/COEP + pthreads（本期不需要）。
- **音频**：首次用户输入 `AudioServer` resume（绕过浏览器自动播放策略）。
- **持久化**：经 `JavaScriptBridge` 写 `window.localStorage`（GDD 指定）；web editor 无 bridge → 自动降级内存。
- **首屏体积**：全量 atlas、≤256px、`.webp/.ctex` 压缩、动画用代码 squash-stretch 替代多帧、音频短 `ogg`；引擎 `.wasm` 经 CDN + brotli 缓存（见 perf-budget §5 口径澄清）。
- **切后台**：`visibility_changed` → 暂停 `physics_tick`，回前台恢复（防"回来即死"，GDD §5）。

### 7.2 TapTap（可选 module）
- `autoload/TapTapSDK.gd`（**可选**，MVP 可不挂）：H5 SDK 桥接，经 `JavaScriptBridge` 接 TapTap Web SDK，提供登录/排行/成就能力；与玩法解耦，仅经 `EventBus`/回调上报。
- 广告走 **TapTap 广告 SDK**（见 §7.4 ProviderTapTap）。
- 接入方式同 Web：SDK 作为 HTML shell 外部 `<script>` 加载，**不进 `.pck`**，对首屏 <5MB 零影响。

### 7.3 微信 / 抖音小程序（H5 容器）
- 小程序以 **WebView / H5 容器** 加载 Godot HTML5 export（同一份 Web 构建产物）；Godot 侧代码不变，仅宿主容器与广告 API 不同。
- 激励视频用小程序原生 API：微信 `wx.createRewardedVideoAd()`、抖音 `tt.createRewardedVideoAd()`（或各自请求式 API）。这些 API 在容器 WebView 内可用 → 由 `AdProviderMiniProgram` 桥接（§7.4）。
- 容器需注入对应 JSBridge 全局（`wx`/`tt`），`AdProviderMiniProgram` 经 `JavaScriptBridge` 调其 `show()`/`onClose` 回调；无法用时优雅降级（不显复活按钮，游戏照常可玩）。
- 持久化：小程序容器内 `localStorage` 可用性与 Web 一致；不可用时降级内存（与 §7.1 同源逻辑）。

### 7.4 激励视频三平台 Provider（呼应 ADR-005）
`AdManager` 维持高层 API（`is_revive_available()` / `request_revive(cb)` / `request_double_reward(cb)`），由**当前平台选择 Provider** 实现 `AdProvider` 抽象（`has_ad('rewarded')` / `show_rewarded()`）：

| Provider | 目标平台 | 接入方式 |
|---|---|---|
| **AdProviderWeb** | Web/HTML5（CrazyGames / Poki / GameDistribution 等发行平台或 H5 中介） | HTML shell 外部 `<script>` 加载 SDK；`JavaScriptBridge.eval()` 调 `hasAd/requestAd`，`create_callback()` 收回调 |
| **AdProviderMiniProgram** | 微信/抖音小程序（H5 容器） | 容器全局 `wx`/`tt` 的 `createRewardedVideoAd()`；`show()` + `onClose` 回调经 `JavaScriptBridge` 桥接 |
| **AdProviderTapTap** | TapTap（Web/H5 SDK） | TapTap 广告 SDK（外部 `<script>`）；同 Web 桥接模式 |

- 三套 Provider 均**不进 Godot `.pck`**（外部 `<script>` 或容器原生 API），对首屏资源 <5MB 零影响；Godot 帧循环不含 SDK JS → 60fps 预算不变。
- **MVP 可禁用广告**：`AdManager.enabled=false` → 核心循环零广告耦合（详见 §8.5）。
- 频率上限与 consent：沿用 §8.4；consent 由平台托管（读平台标志）或自接 CMP（仅读布尔 `ad_consent_given`，不覆盖 CMP 键）。

---

## 8. 广告 / 复活系统（可选，core+ 变现档）
> 变现方式：激励视频（rewarded video）——复活 + 可选额外奖励（双倍）。MVP 不含付费（GDD 已保证无经济失衡）；本系统属 **core+ / 变现档**，以可选 Autoload 接入，MVP 配置 `AdManager.enabled=false`，不影响核心循环与 P1。

### 8.1 接入路径（三平台约束，详见 ADR-005 / §7.4）
- 广告 SDK 作为 **HTML shell 外部 `<script>`**（Web/TapTap）或**容器原生 API**（小程序），**不进 Godot `.pck`** → 对首屏资源 `.pck<5MB` 零影响。
- Godot 经 `JavaScriptBridge` 调平台 API（CrazyGames/Poki/GameDistribution/`wx`/`tt`/TapTap）；SDK→Godot 回调用 `JavaScriptBridge.create_callback()`（**禁止每帧 eval 轮询**）。
- **推荐优先入驻发行平台 SDK**：内置 consent（GDPR/CCPA）托管 + rewarded ad，集成最省；`AdProvider` 抽象层便于换供应商（Web/MiniProgram/TapTap 三套 Provider 见 §7.4）。

### 8.2 模块与耦合
- `AdManager`（Autoload，可选）：高层 API `is_revive_available()` / `request_revive(cb)` / `request_double_reward(cb)`；维护频率上限与 consent 门控；按平台选 `AdProvider*`。
- `AdProvider`（抽象接口）+ `providers/`（Web / MiniProgram / TapTap 具体桥接）：隔离平台差异。
- 经 `EventBus` 与 `CoreLoop` 死亡/结算事件耦合，**不直接参与玩法输入**。

### 8.3 触发点与流程
- `FATAL_HIT` → `CoreLoop` 进 RESULT → `EventBus` 通知 `AdManager` 校验资格：
  1. 本局未复活过（`revive_per_run_max = 1`）；
  2. 当日复活数 < `revive_daily_cap`（**= 3，已与策划侧对齐，锁定；可配，按平台政策**）；
  3. consent 已给 + 广告可用（`AdProvider.has_ad('rewarded')`）。
- 资格满足 → Result UI 显「看广告复活」按钮（**可选，非玩法必需输入**）。
- 用户接受 → `AdManager` **暂停物理 tick**（RESULT 态世界本已冻结）→ 当前平台 `AdProvider.show_rewarded()` → 奖励到账发 `REVIVE_GRANTED` → `CoreLoop` 重置玩家（清附近障碍 + 短暂无敌 ~1s）回 RUNNING；广告失败/无奖励 → 维持 RESULT。
- 「双倍奖励」：RESULT 显最终分时可看广告翻倍（同模式，独立每日上限）。

### 8.4 频率上限与 SaveManager 衔接
- `revive_per_run_max = 1`（复活后再次死亡=真终局，无二次复活）；`revive_daily_cap = 3`（**架构侧锁定值，与策划侧统一；可配，按平台政策**）。
- 计数器存 `SaveManager`：`revive_count_today` + `last_revive_date`（跨日重置）；仅奖励到账后写，不每帧。
- consent/广告偏好存 `SaveManager`（命名空间 `wasteland_escape_save`，与 CMP 键隔离，详见 ADR-004）。

### 8.5 对 P1 / 核心循环的影响
- 复活/双倍奖励均为 RESULT 态**可选 UI 操作**，不新增任何"必须学才能玩"的输入；单指动词链（跑→跳/滑/切轨→躲/收→连/刷→重开）不变。
- MVP 禁用 `AdManager` → 核心循环零广告耦合，P1 完全干净。

---

## 9. 架构评审判定
> **判定：PASS（含 CONCERNS，无 FAIL，无实现阻塞）**

- **CONCERN C1（美术域，非工程阻塞，本次已对齐主题）**：D1 美术圣经须产出**废土/丧尸**基调的纵深素材（天空/远景剪影/赛道纹理），替换旧「霓虹黎明」设定。架构不依赖具体基调，仅依赖"分层大图 + atlas + 伪透视道路"形态，不受影响。
- **CONCERN C2（口径澄清，需主理人）**：首屏 <5MB 是否含 Godot 引擎 `.wasm`（~30–40MB）。建议口径=游戏资源 `.pck`<5MB、引擎另计并 CDN 缓存（perf-budget §5）。
- **CONCERN C3（GDD 缺口，已给回填建议）**：世界尺度 `PPM=50`、拾取物池容量未定义，perf-budget §1/§3.3 已给建议值，待主理人协调 design-strategist 回填。
- **CONCERN C4（Web 单线程）**：重逻辑须主线程，已纳入帧预算（perf-budget §2/§6）；若未来加多线程 AI 需 COOP/COEP 头。
- **CONCERN C5（R5 可读性，playtest 项）**：玩家珊瑚 `#FF6B5E` 与危险红 `#FF3B5C` 同红系，夜调下需实景复核可分辨度——非架构阻塞，留给 playtest。
- **CONCERN C6（变现，非阻塞）**：激励视频依赖外部 SDK/发行平台/小程序容器与 consent（GDPR/CCPA）；`AdManager` 为可选 Autoload、MVP 禁用，不进核心循环、不影响 R4 帧预算与首屏 <5MB（ADR-005）；发行渠道/consent 方案待主理人定后细化。
- **CONCERN C7（本次新增，非阻塞，playtest 项）**：伪透视投影参数（`focal` / `horizonY` / `laneSpacingPx` / `camNear`）与过弯 `yaw`/`cornerDuration` 需 playtest 校准手感与可读性；属可调常量，不影响架构与 R4。
- **阻塞项：无。**

---

## 10. 控制清单（实现前检查项）
见 `control-manifest.md`（独立一小节，实现前逐项勾选；已增补三轨实现项，见其 §D2/§L）。
