# ADR-002 · 性能预算与对象池 / 帧预算策略

- 状态：Accepted（含 R4 回签结论）｜ 作者：程基岩 ｜ 阶段：Phase 3
- 关联：`perf-budget.md`（R4 逐项计算）

## 背景
GDD 标注多项"待程基岩(R4)回签"：Vmax=13、maxLiveObstacles=12、poolSize=24、spawnLookahead=1.5×屏宽。目标 60fps@720p（移动端降级 480p）。需在 Godot Web 下评估可达性并定帧预算与池策略。

## 决策
- **帧预算 16.67ms@60fps**：渲染提交 4–6ms / Process+Physics 2–3ms / GC 尖刺 <0.5ms / HUD 0.5ms / 余量 ~6ms（perf-budget §2）。
- **对象池**：`ObstaclePool` 容量 `poolSize=24`，free-list 激活/回收，**每帧零节点分配**；live 达 `maxLiveObstacles=12` 或池空即停止生成。
- **拾取物独立池** `PickupPool`，建议 `pickupPoolSize=32`（GDD 未给，本 ADR 补）。
- **世界尺度**：引入 `PPM=50`（px/m）设计常量（perf-budget §1），统一 GDD 的"米"与"世界像素"。
- **生成预读**：`spawnLookahead=1.5×屏宽` 保持。
- R4 各项初值**判定可达**，不改（Vmax=13 / maxLive=12 / pool=24 / lookahead=1.5×）；可选 `maxLiveObstacles` 降到 10 更稳。

## 理由
- 池化消除 per-frame `queue_free/instantiate` 的 GC 抖动，是 Web 稳 60fps 的前提。
- 计算表明最大密度下同屏存活 ~7–8 个障碍（perf-budget §3.2），12 给 1.5× 余量；24 池 = 2× live，标准余量。
- PPM=50 使 720p 玩家占 90px、480p 占 60px，清晰可读；近失带 24px 世界 ≈0.48m 合理。

## 后果
- 池外停止生成 → 极端情况（回收滞后）瞬时密度略降，但保帧率，可接受。
- 单线程 Web 下重逻辑须主线程；若未来加多线程 AI 需 COOP/COEP 头（本期不需要）。
- 首屏 <5MB 口径需主理人确认（引擎二进制是否计入，perf-budget §5）。
