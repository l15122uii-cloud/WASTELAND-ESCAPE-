# Epic / Story 拆分索引 ·《WASTELAND ESCAPE / 废土逃生》

> 阶段：Phase 4 预制作（Epic/Story 拆分）｜ 作者：程基岩（engineering-lead-3）
> 配套：architecture.md / adr-001..005 / control-manifest.md / perf-budget.md / autoload/Tuning.gd / design/gdd/{core-loop,combo-scoring,obstacle-gen}.md
> 用法：每个 Story 动手前先过 control-manifest.md 对应检查项；AC 逐条可测，测试证据见 docs/architecture/test-plan.md。

## 拆分原则
- 一个 Epic = 一个架构子系统（对应 architecture.md §3 模块划分 + 单一 ADR 主线）。
- 每个 Story 嵌 **GDD/ADR 溯源**（保证需求可追溯）、**验收标准 AC**（可测）、**规模 S/M/L**、**依赖**。
- 规模估算：S ≤ 0.5d、M ≈ 0.5–1.5d、L ≈ 1.5–3d（单人日，含联调与自测）。
- 垂直切片（production/vertical-slice.md）覆盖的 Story 标 ⭐；MVP 层 Story 标 [MVP]、核心档标 [CORE]。

## Epic 一览
| Epic | 主题 | 主 ADR | Story 数 | 文件 |
|---|---|---|---|---|
| **CoreRunLoop** | 顶层状态机 + 速度模型 + 每帧推进 + 事件路由 + 死亡重开 | ADR-001/002 | 6 | `core-run-loop.md` |
| **LaneCornerSystem** | 伪透视投影 + 三轨系统 + 过弯 + 玩家运动学 | ADR-001/003 | 7 | `lane-corner-system.md` |
| **ObstacleGeneration** | 对象池 + 生成调度 + 障碍类型 + 可解性 + 近失 | ADR-002 | 8 | `obstacle-generation.md` |
| **ComboScoring** | 连击状态机 + 倍率 + 衰减 + 计分 | — | 6 | `combo-scoring.md` |
| **ReviveAd** | 复活/激励视频（AdManager + Provider + 上限） | ADR-005 | 6 | `revive-ad.md` |
| **Persistence** | 存档（最佳记录/里程碑/复活计数） | ADR-004 | 5 | `persistence.md` |

## 依赖总图（关键路径）
```
Tuning.gd (真值源) ──► 全部 Epic
EventBus.gd ──► CoreRunLoop / ComboScoring / ReviveAd
CoreRunLoop ──► LaneCornerSystem(CornerController) / ObstacleGeneration(Spawner) / Persistence / ReviveAd
LaneCornerSystem(LaneSystem) ──► ObstacleGeneration(可解性/过弯约束)
ObstacleGeneration ──► ComboScoring(近失/拾取事件)
Persistence ──► ReviveAd(复活计数/consent)
```

## 垂直切片命中的 Epic/Story（⭐）
- CoreRunLoop：CRL-1（状态机）、CRL-3（每帧推进/计分）、CRL-4（事件路由）、CRL-5（死亡重开）
- LaneCornerSystem：LCS-1（投影）、LCS-2（三轨+插值）、LCS-3（锁中轨）、LCS-4（输入映射）、LCS-5（跳/滑/二段跳）、LCS-6（过弯）
- ObstacleGeneration：OBG-1（障碍池）、OBG-2（拾取池）、OBG-4（Blocker 单类）、OBG-6（近失 flank）、OBG-7（过弯中轨约束）
- ComboScoring：COM-1（状态机/倍率）、COM-2（衰减）、COM-3（消费事件）、COM-4（计分）、COM-6（flank +1）
- ReviveAd：RAD-1/3/4/5/6（复活链路 + 上限强制）
- Persistence：PER-1/2/3/4/5（存档 + 复活计数）
