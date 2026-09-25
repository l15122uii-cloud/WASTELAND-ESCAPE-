# 控制清单（实现前检查项）· P3-ENG-01

> 配套：architecture.md / ADR-001~004 / perf-budget.md
> 用法：每个 Story/模块动手前逐项勾选；任一 ❌ 未满足则先解决再写代码。

## A. 引擎与导出（ADR-001 / ADR-002）
- [ ] `project.godot` 渲染方法 = `gl_compatibility`（Web 唯一稳定路径，否则黑屏）
- [ ] 视口 base 1280×720，stretch `mode=viewport` / `aspect=expand`
- [ ] Web 导出预设已建；`.wasm` 启用 brotli/gzip
- [ ] 全量资源走 atlas，单图 ≤256px，压缩 `.webp/.ctex`

## B. 单一真值源（一致性红线）
- [ ] 速度模型 `V(d,combo)` 仅定义在 `CoreLoop`/`SpeedModel`，ObstacleGen/ComboScoring 只读不重定义
- [ ] `nearMissBand/Tier` 仅定义在 `ObstacleGen`，ComboScoring 引用不重定义
- [ ] 全部 GDD 数值集中在 `autoload/Tuning.gd`（含新增 `PPM=50`）
- [ ] 模块间仅经 `EventBus` 通信，无直接跨模块字段耦合

## C. 对象池（ADR-002 / R4）
- [ ] `ObstaclePool` 预实例化 `poolSize=24`，free-list 激活/回收，**每帧零 `queue_free`**
- [ ] live 达 `maxLiveObstacles=12`（或 10）或池空 → 停止生成
- [ ] 新增 `PickupPool`（建议 32），不与障碍池混用
- [ ] 障碍回收判定用"越过玩家身后回收余量"，非立即销毁

## D. 输入抽象（ADR-003 / P1）
- [ ] 玩法/UI **只订阅** `InputManager` 抽象动作，绝不读 `InputEvent` 原始设备
- [ ] `SwipeDetector` 仅识别主指、忽略第二触点；含最小位移 + 时长去抖
- [ ] 键盘映射产出同动作事件；MVP 仅上滑/下滑即可存活

## D2. 三轨身后视角实现（新增，架构 §6 / ADR-003）
- [ ] `LaneSystem` 三轨状态 `lane∈{0,1,2}`，平滑插值到目标车道 `x`；边界夹取
- [ ] `LaneSystem.force_center()` + `set_input_locked()`：CORNER/REVIVE 锁横向输入、强制中轨
- [ ] `CornerController` 由 `CoreLoop` 里程触发；`yaw` 旋转插值；发 `CORNER_ENTER`/`CORNER_EXIT`（EventBus 新增信号）
- [ ] `PlayerController` 消费 LaneInput：`LANE_LEFT/RIGHT`→`switch_lane`，`JUMP/SLIDE`→运动学
- [ ] `core/projection.gd` 伪透视投影 `project(x,z)→(sx,sy,scale)`；参数 `focal/horizonY/laneSpacingPx/camNear` 入 `Tuning`
- [ ] 障碍/拾取每帧经投影写屏幕坐标 + `scale`；**不使用 Node3D / 真实 3D 相机**（gl_compatibility 友好）
- [ ] 过弯期间世界继续推进（`z` 递减），仅车道锁定；REVIVE(RESULT) 整体冻结
- [ ] 手势四向（左/右/上/下）映射 LaneInput；键盘 `A/D/W/S` + 方向键同映射

## E. 持久化（ADR-004 / D4）
- [ ] `SaveManager` 经 `JavaScriptBridge` 写 `window.localStorage`，键带 `schema_version`
- [ ] 所有 localStorage 访问包 `try/catch`；bridge 不可用/隐私模式 → 降级内存不阻塞
- [ ] 仅 `RESULT` 态写盘，不每帧 IO

## F. Web 运行时（perf-budget §6）
- [ ] 禁用 `Thread`（单线程约束）
- [ ] 首次输入 `AudioServer` resume（自动播放策略）
- [ ] `visibility_changed` 暂停物理 tick，回前台恢复
- [ ] 移动端 480p 兜底 + 30fps 下限

## G. 性能红线（美术 / R4）
- [ ] 单屏 draw call ≤50（合批 + atlas 实测）
- [ ] 同屏粒子 ≤120（`ParticlePool` 硬上限）
- [ ] 无实时阴影（仅 BlobShadow）
- [ ] 首屏资源 `.pck` <5MB（口径按主理人确认；引擎 `.wasm` 另计 CDN 缓存）

## H. 广告 / 复活（可选，core+ 档，ADR-005）
- [ ] MVP 配置 `AdManager.enabled=false`，核心循环零广告耦合
- [ ] 广告 SDK 仅作 HTML shell 外部 `<script>` 加载，不进 `.pck`
- [ ] Godot↔SDK 回调用 `JavaScriptBridge.create_callback()`，禁止每帧 eval
- [ ] 请求广告前暂停物理 tick；仅 RESULT 态触发，避免穿隧
- [ ] consent 门控：平台托管则读平台标志；自接 CMP 则仅读 `ad_consent_given`，绝不覆盖 `tcString`
- [ ] `revive_per_run_max=1`、`revive_daily_cap=3`（可配），计数存 SaveManager，仅奖励到账后写
- [ ] 复活后给玩家短暂无敌 + 清附近障碍，防即时再死
- [ ] `wasteland_escape_save` 与 CMP 键命名空间隔离（与 ADR-004 同键名，已对齐）
