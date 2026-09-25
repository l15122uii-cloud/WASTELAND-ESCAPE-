# Epic · ReviveAd（复活 / 激励视频）

> 对应架构：architecture.md §7.4/§8、ADR-005。
> 锁定值：`revive_per_run_max=1`、`revive_daily_cap=3`（已与策划统一，可配按平台政策）。
> 可选档（core+ 变现档）：MVP 配置 `AdManager.enabled=false`，核心循环零广告耦合（ADR-005 §9）。

---

### RAD-1 · AdManager 可选 Autoload + 高层 API
- 简述：`AdManager`（可选 Autoload）维护高层 API `is_revive_available()` / `request_reveal(cb)` / `request_double_reward(cb)`；经 EventBus 接 CoreLoop 死亡/结算，不参与玩法输入。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.2、ADR-005 §4/§8。
- 验收标准（AC）：
  1. `AdManager.enabled=false`（MVP 默认）→ 核心循环零耦合，Result UI 不显示复活按钮（优雅降级）。
  2. FATAL_HIT→RESULT 经 EventBus 通知 AdManager 校验资格（不引入玩法输入）。
  3. `is_revive_available()` 综合 per_run/daily/consent/ad 可用性返回布尔。
- 规模：M
- 依赖：EventBus、SaveManager（PER-1/3/4）
- 切片：⭐（切片启用最简复活链路验证上限）

### RAD-2 · AdProvider 抽象接口 + 三平台 Provider
- 简述：`AdProvider` 抽象（`has_ad('rewarded')` / `show_rewarded()`）；三套实现 AdProviderWeb / AdProviderMiniProgram / AdProviderTapTap；构建期探测运行环境选 Provider；均不进 `.pck`。
- GDD/ADR 溯源：architecture.md §7.4、ADR-005 §1/§8（三平台对照）、control-manifest §H。
- 验收标准（AC）：
  1. 三 Provider 同一 `has_ad`/`show_rewarded` 接口；Web 经 `JavaScriptBridge.eval`+`create_callback`；小程序经 `wx/tt.createRewardedVideoAd`+`onClose`。
  2. SDK 仅 HTML shell 外部 `<script>` 或容器原生 API，不进 `.pck`（对首屏 <5MB 零影响）。
  3. SDK 不可用/consent 拒绝 → `is_revive_available()=false`，游戏照常可玩（降级）。
  4. Godot↔SDK 回调用 `JavaScriptBridge.create_callback`，禁止每帧 eval 轮询（control-manifest §H）。
- 规模：L
- 依赖：RAD-1、AdManager
- 切片：部分（切片用 Web Provider 或 mock Provider；小程序/TapTap Provider 可后置）

### RAD-3 · 复活资格校验（per_run_max=1, daily_cap=3, consent/ad）
- 简述：校验①本局未复活（`revive_per_run_max=1`）②当日复活数 < `revive_daily_cap(=3)` ③consent 已给 + 广告可用；三者皆满足才显复活按钮。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.3/§8.4、ADR-005 §6/§9、Tuning.gd（revive_*）。
- 验收标准（AC）：
  1. **单测（强制）**：当日第 4 次请求 revive → `is_revive_available()=false`（daily_cap=3 硬上限）。
  2. **单测（强制）**：本局已复活 1 次后再死亡 → 不再提供复活（per_run_max=1）。
  3. consent 拒绝 / 广告不可用 → 不显复活按钮。
  4. 计数仅奖励到账后写 SaveManager，不每帧（ADR-004 扩展 / ADR-005 §6）。
- 规模：M
- 依赖：RAD-1、SaveManager（PER-5）
- 切片：⭐（复活上限强制=3天/1局 为切片验收硬项，见 test-plan 烟雾清单）

### RAD-4 · REVIVE_GRANTED → CoreLoop 重置玩家回 RUNNING
- 简述：广告奖励到账发 `REVIVE_GRANTED` → CoreLoop 重置玩家（清附近障碍 + 短暂无敌 REVIVE_invuln=1s）回 RUNNING；combo 归零、距离保留。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.3、ADR-005 §5、Tuning.gd（REVIVE_invuln）。
- 验收标准（AC）：
  1. `REVIVE_GRANTED` → 玩家回 RUNNING，距离保留、combo 归零、附近障碍清除。
  2. 复活后 ~1s 无敌（防即时再死，control-manifest §H）。
  3. 广告失败/无奖励 → 维持 RESULT（不误复活）。
- 规模：M
- 依赖：RAD-3、CRL-1（状态机）、OBG（清障）
- 切片：⭐（切片复活流程必要）

### RAD-5 · 请求广告前暂停物理 tick（RESULT 态冻结）
- 简述：请求广告前 pause 物理 tick（RESULT 态世界本已冻结）；广告关闭后依结果恢复 RUNNING 或维持 RESULT；无穿隧风险。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.3、ADR-005 §5、control-manifest §H。
- 验收标准（AC）：
  1. 请求广告时 `get_tree().paused=true` 或停 CoreLoop 物理；RESULT 态世界不推进。
  2. 广告关闭后依 `REVIVE_GRANTED` 恢复 RUNNING（清障+无敌）或维持 RESULT。
  3. 无「广告播放时世界推进/穿隧/回来即死」。
- 规模：S
- 依赖：RAD-4、CRL-6（暂停机制）
- 切片：⭐ [MVP]

### RAD-6 · 复活计数持久化（仅到账写，跨日重置）
- 简述：`revive_count_today` + `last_revive_date` 存 SaveManager（同一 `wasteland_escape_save` JSON，命名空间隔离 CMP 键）；仅奖励到账后写；跨日自动重置。
- GDD/ADR 溯源：core-loop.md §6.1、architecture.md §8.4、ADR-004 扩展、ADR-005 §7、Tuning.gd。
- 验收标准（AC）：
  1. 仅 `REVIVE_GRANTED` 到账后 +1 `revive_count_today`（不每帧、不阻塞）。
  2. `last_revive_date` 跨日 → `revive_count_today` 重置为 0。
  3. `wasteland_escape_save` 与 CMP 键命名空间隔离（绝不写 tcString，ADR-004/005）。
- 规模：S
- 依赖：RAD-3、SaveManager（PER-1/5）
- 切片：⭐（复活上限持久化是切片验收硬项）
