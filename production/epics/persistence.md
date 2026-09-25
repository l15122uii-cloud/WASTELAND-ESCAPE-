# Epic · Persistence（持久化）

> 对应架构：architecture.md §3 SaveManager、§7.1、ADR-004。
> 键：`wasteland_escape_save`（JSON + schema_version）；命名空间隔离 CMP 键。
> 写时机：仅 RESULT 态一次性写，不每帧 IO（ADR-004）。

---

### PER-1 · SaveManager Autoload + JavaScriptBridge localStorage 读写
- 简述：经 `JavaScriptBridge.eval("window.localStorage")` 读写键 `wasteland_escape_save`（JSON + schema_version）；web editor 无 bridge → 自动降级内存。
- GDD/ADR 溯源：core-loop.md §5.2、architecture.md §7.1、ADR-004 §决策/后果、control-manifest §E。
- 验收标准（AC）：
  1. `load()` 读 `wasteland_escape_save`；`save_best()` 写最佳距离/分数。
  2. 所有 localStorage 访问包 `try/catch`（防隐私模式 SecurityError 中断）。
  3. `JavaScriptBridge` 不可用 → 降级内存字典，不阻塞游戏（ADR-004 降级链）。
  4. 键名带 `schema_version`，便于迁移。
- 规模：M
- 依赖：Tuning.gd
- 切片：⭐ [MVP]

### PER-2 · 内存降级（localStorage 不可用 → 内存字典）
- 简述：localStorage 不可用/写入失败 → 内存字典记录，并提示「本次成绩不留存」，不阻塞游戏。
- GDD/ADR 溯源：core-loop.md §5.2（边界 2）、architecture.md §7.1、ADR-004 后果。
- 验收标准（AC）：
  1. 模拟隐私模式抛错 → 游戏继续，记录仅留内存。
  2. 提示文案出现（不阻塞主循环）。
- 规模：S
- 依赖：PER-1
- 切片：⭐ [MVP]（Web 隐私模式真实场景）

### PER-3 · 数据结构（best_distance/best_score/milestones + schema_version）
- 简述：`{ schema_version, best_distance, best_score, milestones:{distance:[...],best:[...],combo_peak:[...]} }`；分数 64 位/双精度，显示格式化。
- GDD/ADR 溯源：core-loop.md §4（里程碑阈值 D4）、combo-scoring.md §4/§7、ADR-004 §决策。
- 验收标准（AC）：
  1. 结构含 best_distance/best_score/milestones 三子集（距离/最佳/连击峰值）。
  2. schema_version 不匹配旧版 → 安全迁移或重建（不崩）。
- 规模：S
- 依赖：PER-1
- 切片：⭐（切片需 best_distance/score 展示）

### PER-4 · 仅 RESULT 态写盘
- 简述：死亡/重开前一次性写盘；不每帧 IO；不重载场景资源即可重开（对象池复用，满足 <2s）。
- GDD/ADR 溯源：core-loop.md §5.2、architecture.md §7.1、ADR-004 后果、R4 帧预算。
- 验收标准（AC）：
  1. grep/桩校验：RUNNING 每帧无 localStorage 写调用。
  2. 仅 RESULT 态（死亡/重开前）写一次。
- 规模：S
- 依赖：PER-1、CRL-5
- 切片：⭐ [MVP]

### PER-5 · 复活计数字段（revive_count_today/last_revive_date）+ 跨日重置
- 简述：同 `wasteland_escape_save` JSON 扩展字段 `revive_count_today`、`last_revive_date`、`revive_offered_total`（统计）、`ads_enabled`（可选偏好）；仅奖励到账写。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.4、ADR-004 扩展、ADR-005 §7、Tuning.gd。
- 验收标准（AC）：
  1. `record_revive()` 仅到账后 +1 `revive_count_today`；跨日 `last_revive_date` 变更 → 重置 0。
  2. `revive_per_run_max`/`revive_daily_cap` 可从 Tuning 配（按平台政策）。
  3. 与 CMP 键隔离，SaveManager 仅读 `ad_consent_given` 布尔（绝不写 tcString）。
- 规模：S
- 依赖：PER-1、RAD-3（复活计数写回）
- 切片：⭐（复活上限持久化是切片验收硬项）
