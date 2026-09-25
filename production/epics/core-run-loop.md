# Epic · CoreRunLoop（核心循环编排器）

> 对应架构：architecture.md §3 CoreLoop / §1 目录 core/；ADR-001/002。
> 真值源：速度模型 `V(d,combo)` 只在本 Epic 定义（一致性红线）；`autoload/Tuning.gd` 只读。

---

### CRL-1 · 顶层状态机（BOOT→MENU→COUNTDOWN→RUNNING⇄CORNER→RESULT）
- 简述：实现核心循环状态机，编排 BOOT / MENU / COUNTDOWN / RUNNING / CORNER（RUNNING 子状态）/ RESULT；状态切换经 EventBus 发 `STATE_CHANGED`；REVIVE 仅作为 RESULT 的可选分支。
- GDD/ADR 溯源：core-loop.md §2.1（状态机图）、architecture.md §3 CoreLoop、ADR-001。
- 验收标准（AC）：
  1. 启动进 BOOT→MENU；点击开始进 COUNTDOWN(3s)→RUNNING。
  2. RUNNING 中达过弯里程自动进 CORNER 子状态（不离开 RUNNING）；过弯结束回 RUNNING。
  3. FATAL_HIT → RESULT；RESULT 一键重开 → COUNTDOWN → RUNNING。
  4. 每次状态切换发 `EventBus.STATE_CHANGED(prev, next)`，HUD/UI 仅订阅该信号（不持有状态）。
  5. 过弯中死亡 → RESULT 时清除 CORNER 锁定/视角旋转残留（core-loop.md §5.5），下一局无转角偏移。
- 规模：L
- 依赖：EventBus（autoload）、Tuning.gd
- 切片：⭐ [MVP]

### CRL-2 · 速度模型 V(d,combo) 单一真值源
- 简述：`SpeedModel.V(d,combo) = min(Vmax, V0 + k_d·d) · (1 + k_c·min(combo, comboFlowCap))`，常量全取 Tuning。
- GDD/ADR 溯源：core-loop.md §2.4/§4、architecture.md §0 一致性红线、perf-budget.md §3.1。
- 验收标准（AC）：
  1. `V(0,0)=V0(7.0)`；`V` 随 `d` 单调不减、封顶 `Vmax(13.0)`。
  2. `k_c·combo` 流速加成 ≤ 封顶；`V_peak ≤ 14.3 m/s`（R4 已回签可达）。
  3. ObstacleGen / ComboScoring **只读** `V`，不在本模块外重定义（grep 校验无重复公式）。
- 规模：S
- 依赖：Tuning.gd
- 切片：⭐（被 CRL-3 调用）[MVP]

### CRL-3 · 每帧推进与计分（d+=V·dt；score+=V·dt·m）
- 简述：RUNNING 每帧 `d += V·dt`；横向 lane 插值不影响 `V`；`score += V·dt·m`（m 取自 ComboScoring）；每帧向 ObstacleSpawner 供 `(V,d,tier,lane,inCorner)`，向 ComboScoring 调 `tick(dt)`。
- GDD/ADR 溯源：core-loop.md §2.3/§2.4、combo-scoring.md §2.3、architecture.md §4。
- 验收标准（AC）：
  1. 距离 `d` 每帧单调增；速度仅由 `V(d,combo)` 决定，切轨不改变 `d` 速率。
  2. `score` 每帧按 `V·dt·m` 累加（m 来自 ComboScoring 当前倍率）。
  3. `V=0` 除零保护（`max(V, ε)`），理论不触发但防御性存在。
  4. `d`/`score` 用 64 位/双精度，封顶显示格式化（k/m），无溢出（core-loop.md §5.4）。
  5. 每帧零分配（热路径不 new 对象），满足 perf-budget §2 GC 尖刺 <0.5ms。
- 规模：M
- 依赖：CRL-1、CRL-2、ComboScoring(COM-1/2/4)
- 切片：⭐ [MVP]

### CRL-4 · EventBus 事件路由（FATAL_HIT/NEAR_MISS/PICKUP/SPAWN/LANE_CHANGED/CORNER_*/REVIVE_GRANTED）
- 简述：CoreLoop 接收 ObstacleGen 事件并路由——`NEAR_MISS`/`PICKUP`/`DOUBLE_JUMP` 转发 ComboScoring；`FATAL_HIT` 触发 RESULT；`CORNER_ENTER/EXIT` 联动 LaneSystem；死亡经 EventBus 通知 AdManager。
- GDD/ADR 溯源：core-loop.md §6、architecture.md §4 数据流、ADR-005 §4。
- 验收标准（AC）：
  1. 模块间仅经 EventBus 通信（grep 校验无跨模块直接字段耦合）。
  2. `NEAR_MISS(proximity)` / `PICKUP(type)` 每帧被转发给 ComboScoring 且驱动 combo/m。
  3. `FATAL_HIT` → CoreLoop 切 RESULT（core-loop.md §5.1：仅真实碰撞致死，失误≠死亡）。
  4. 新增信号 `CORNER_ENTER/EXIT`、`LANE_CHANGED`、`REVIVE_GRANTED` 已在 EventBus 声明并触发。
- 规模：M
- 依赖：EventBus（autoload）、ComboScoring、LaneSystem（LCS-2）、CornerController（LCS-6）
- 切片：⭐ [MVP]

### CRL-5 · 死亡结算与一键重开（<2s，对象池复用）
- 简述：FATAL_HIT → RESULT 写盘最佳记录 → 一键重开清空世界实体/连击/距离，保留 localStorage 最佳与里程碑；不重载场景资源（对象池复用）。
- GDD/ADR 溯源：core-loop.md §5.2（重开<2s）、ADR-004（仅 RESULT 写盘）、perf-budget R4。
- 验收标准（AC）：
  1. RESULT→RUNNING 重开耗时 < 2s（实测从点击到可操作）。
  2. 重开不清空 localStorage 最佳/里程碑；对象池节点不 `queue_free`（复用，零分配）。
  3. 死亡瞬间 SaveManager 落盘最佳距离/分数（仅 RESULT 态写一次，不每帧）。
- 规模：M
- 依赖：CRL-1、ObstaclePool（OBG-1）、SaveManager（PER-1/4）
- 切片：⭐ [MVP]

### CRL-6 · Web 运行时保护（切后台暂停 / 音频 resume / 480p 兜底）
- 简述：tab blur（`visibility_changed`）暂停物理 tick，回前台恢复（防"回来即死"）；首次输入 `AudioServer` resume；移动端 480p 兜底 + 30fps 下限。
- GDD/ADR 溯源：core-loop.md §5.1、architecture.md §7.1、perf-budget §6、control-manifest §F。
- 验收标准（AC）：
  1. `visibility_changed=false` → 暂停 CoreLoop 物理 tick；回 `true` 恢复，期间游戏世界不推进。
  2. 首次 `InputEvent` → `AudioServer` resume（绕过自动播放策略）。
  3. 移动端检测到低宽 → 降 480p + 30fps 下限（control-manifest §F 勾选）。
  4. 暂停期间 ComboScoring 衰减窗口不走时（combo-scoring.md §5）。
- 规模：M
- 依赖：CRL-1
- 切片：⭐（Web 平台必带）[MVP]
