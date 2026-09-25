# ADR-004 · 持久化方案（最佳记录 / 跨局里程碑）

- 状态：Accepted ｜ 作者：程基岩 ｜ 阶段：Phase 3
- 依赖：D4（单局无限距离 + 跨局里程碑）、GDD §5 边界处理、P3-ENG-02（广告/复活持久化）

## 背景
D4 要求本地持久化单局最佳距离/分数 + 跨局累计里程碑（皮肤/称号/特效解锁）。GDD 明确写 `localStorage`，且要求"localStorage 不可用时降级内存、不阻塞游戏"。Web 隐私模式/写入失败需优雅降级。

## 决策
- **SaveManager（Autoload）** 经 `JavaScriptBridge.eval("window.localStorage")` 读写键 `wasteland_escape_save`（JSON + `schema_version` 字段）。
- 数据结构：`{ best_distance, best_score, milestones:{distance:[...],best:[...],combo_peak:[...]} }`；分数用 64 位整数/双精度，显示格式化（k/m）。
- **降级链**：localStorage 成功 → 落盘；`JavaScriptBridge` 不可用（web editor 调试）或抛错/隐私模式 → 降级为**内存字典**，并提示"本次成绩不留存"，**不阻塞游戏**。
- 写入时机：仅 `RESULT` 态（死亡/重开前）一次性写，避免每帧 IO。
- 不重新加载场景资源即可重开（对象池复用），满足 GDD"重开 <2s"。

## 理由
- GDD 指定 localStorage，且跨会话稳定；Godot `user://` 在 Web 映射 IndexedDB（语义/配额不同），故直连 JS bridge 更贴需求。
- 内存降级保证隐私模式下仍可玩，符合 GDD 边界处理。
- 仅死亡时写，规避每帧持久化开销与写竞争。

## 后果
- 依赖 JS 运行环境；web editor 无 bridge 自动降级内存，便于本地调试（无需真实浏览器）。
- 需 `try/catch` 包裹所有 localStorage 访问，防隐私模式抛 `SecurityError` 中断游戏。
- 数据无服务端校验（MVP 无后端），作弊仅影响本地记录，符合"无经济失衡"范围。

## 扩展（P3-ENG-02：广告 / 激励视频持久化）
- **新增存储字段**（同一 `wasteland_escape_save` JSON，命名空间隔离）：`revive_count_today`、`last_revive_date`、`revive_offered_total`（统计）、`ads_enabled`（可选用户偏好）。
- **consent 边界**：若入驻发行平台（CrazyGames / Poki / GameDistribution），consent 由其托管，`SaveManager` 不碰 CMP 键；若自接 H5 中介需 HTML shell 内 CMP，consent 串存于 CMP 自有键（如 IAB `tcString`），`SaveManager` **仅读布尔 `ad_consent_given`**（由 CMP/平台回填），绝不写/覆盖 CMP 键，避免破坏 GDPR/CCPA 合规。
- **写入时机**：复活计数仅在该次广告奖励到账后（RESULT 态）更新，不每帧、不阻塞。
- **隔离原则**：`wasteland_escape_save` 只含游戏数据，与 CMP / localStorage 其它键互不干扰，隐私模式下仍降级内存不阻塞。
