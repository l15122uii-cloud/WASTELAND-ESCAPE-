# Epic · ComboScoring（连击计分）

> 对应架构：architecture.md §3 ComboScoring；无独立 ADR（受 obstacle-gen ADR-002 与 core-loop 编排）。
> 真值源：`nearMissBand/Tier`、`PPM=50` 仅引用 obstacle-gen / core-loop，本 Epic 不重定义（一致性红线）。
> 设计要点：本系统无任何独立输入（P1），纯被动消费事件。

---

### COM-1 · 连击状态机（IDLE/BUILDING）+ 倍率 m(combo)
- 简述：`IDLE(combo=0,m=1.0)→BUILDING(combo>0)`；`m(combo)=min(m_max,1+step·combo)`；BUILDING 窗口 T 到期→IDLE（连击清零、m 回 1.0，非致命软压力）。
- GDD/ADR 溯源：combo-scoring.md §2.1/§2.3/§4（step=0.10/m_max=5.0/comboCap=40）、core-loop §2.2。
- 验收标准（AC）：
  1. `m(0)=1.0`；`m` 随 combo 线性增，combo≥40 封顶 m_max=5.0。
  2. 窗口 T 到期→combo=0、m=1.0（非致命）。
  3. FATAL_HIT→局终，连击随局结束（规则保留，局内不单独处理）。
- 规模：M
- 依赖：Tuning.gd（引用 nearMiss*）、CRL-3（供 V/m 计分）
- 切片：⭐ [MVP]

### COM-2 · 衰减窗口 tick(dt) 驱动
- 简述：每帧 `tick(dt)` 推进衰减窗口；暂停（tab blur）不走时；前期建议放宽 T（3.5–4s）随距离收至 2.5s 避免 P3 早期劝退。
- GDD/ADR 溯源：combo-scoring.md §2.1/§4/§8（早期过载 CONCERN）、core-loop.md §5.4。
- 验收标准（AC）：
  1. 每帧 `tick(dt)` 推进窗口；距上次事件 > T → 清零。
  2. 暂停期间（CRL-6 visibility_changed）窗口不走时。
  3. T 前期（前 ~5 局）放宽至 3.5–4s，随距离收敛 2.5s（playtest 校准）。
- 规模：S
- 依赖：COM-1
- 切片：⭐ [MVP]

### COM-3 · 消费近失/拾取/技巧事件
- 简述：订阅 `NEAR_MISS(proximity)` / `PICKUP(supply/medkit)` / `DOUBLE_JUMP`；按 `nearMissTier` 分档给 combo/加分；切轨（LANE_SWITCH）不产事件也不清零。
- GDD/ADR 溯源：combo-scoring.md §2.2/§6、obstacle-gen.md §2.4（事件接入点）、architecture.md §4。
- 验收标准（AC）：
  1. `NEAR_MISS(graze)`：d≤tier→+2，否则+1；`flank`→+1（低风险）。
  2. `PICKUP(supply)`→+1、`PICKUP(medkit)`→+2（CORE 档）；`DOUBLE_JUMP`→+1（CORE 档）。
  3. `LANE_SWITCH` 不改变状态机（不+combo，不清零）；连续切轨不中断连击。
  4. 同帧多事件累加不丢（combo-scoring.md §5）。
- 规模：M
- 依赖：EventBus、OBG-6（近失事件）、CRL-4（路由）
- 切片：⭐（flank +1 在 MVP 即引入）

### COM-4 · 计分公式（score += V·dt·m + Σ eventBonus）
- 简述：每帧距离分 `V·dt·m` 由 CoreLoop 调用累加；事件额外加分 `Σ eventBonus`（supplyBonus=10/medkitBonus=25/nearMissBonus=15 或 30）。
- GDD/ADR 溯源：combo-scoring.md §2.3/§4、core-loop.md §2.4。
- 验收标准（AC）：
  1. `score += V·dt·m` 每帧执行（V 来自 CoreLoop 真值，m 来自本模块）。
  2. 事件加分按类型累加（近失 15/30、补给 10、急救包 25）。
  3. 分数 64 位/双精度，封顶格式化（k/m）。
- 规模：S
- 依赖：COM-1、CRL-3
- 切片：⭐ [MVP]

### COM-5 · 跨轨连击不中断（切轨透明）
- 简述：连击归属只随计分事件推进；切轨本身既非事件也非断连；「连击在当前轨累计」以玩家越障时当前轨为参考。
- GDD/ADR 溯源：combo-scoring.md §2.1/§2.2（三轨语义）。
- 验收标准（AC）：
  1. 单测：连续切轨 5 次（无事件）后连击不变、未清零。
  2. 近失判定以越障瞬间 current_lane 为参考（同轨 graze / 相邻轨 flank / 当前轨 PICKUP）。
- 规模：S
- 依赖：COM-1、LCS-2
- 切片：⭐（切片切轨频繁，须验证不误断）

### COM-6 · MVP 提前引入 flank 近失 +1（低风险贴脸心智）
- 简述：MVP 即引入相邻轨掠过近失 +1（零额外操作成本，天然教玩家建立贴脸心智）；高风险同轨贴脸 +2 与急救包星延迟至 CORE。
- GDD/ADR 溯源：combo-scoring.md §7（MVP 设计变更）、obstacle-gen.md §7（MVP）。
- 验收标准（AC）：
  1. MVP 下 flank +1 触发即 score/combo 增长（无需玩家主动冒险）。
  2. 同轨贴脸 +2 / 急救包 / 星 在 `tier=MVP` 关闭，仅 CORE 启用（门控由 CoreLoop 下发 tier）。
  3. 防主导策略：flank 恒 +1 无代价须由生成器频繁封堵当前轨逼迫反应（OBG-5 协同，playtest 校准）。
- 规模：S
- 依赖：COM-3、OBG-6、CoreLoop(tier 门控)
- 切片：⭐ [MVP]
