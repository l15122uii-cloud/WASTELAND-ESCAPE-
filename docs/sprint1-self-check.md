# Sprint 1 静态自审报告 · WASTELAND ESCAPE / 废土逃生

> 审查人：程基岩（engineering-lead-3-2）
> 范围：全部 Sprint 1 代码（主理人补写的 14 个文件 + 4 个 edited core + 8 个原始 core）
> 方法：纯静态评审（本工作区无 Godot 运行时，无法真机解析/运行；结论为静态推理，置信度高但非真机确认）
> 配套约束：control-manifest §B/D/D2/E/F/H、ADR-003/004/005、test-plan §3/§5.2、Tuning.gd、event_bus.gd

---

## 0. 结论速览

- **发现并修复 6 处问题**（2 处致命编译/加载错误、2 处会令 S10 硬门禁直接 fail 的测试加载错误、1 处类型误用、1 处过弯可解性逻辑缺陷）。
- **修复后**：GUT headless 下 S1/S5/S8/S9/S10/S11/S12 逻辑上应全绿；S9、S10 两个硬门禁在补齐测试基建后应稳定通过。
- **仍不能验证**（无 Godot 运行时）：真机解析、主场景启动、Web localStorage、复活完整链路、性能预算。
- **关键前提**：需先安装 GUT addon + 建 `test_runner.tscn`（注册 4 个 autoload）；并注意 `test_revive_caps` 的日期依赖。

---

## (a) 已发现并修复的问题（file:line）

| # | 文件:行 | 严重度 | 问题 | 修复 |
|---|---|---|---|---|
| **F1** | `entities/obstacle_spawner.gd:19` | 致命·编译 | `var player: Node` 之后调用 `player.current_lane()` / `player.is_invulnerable()`——这两个方法不属于 `Node`，在 GDScript 4.x 严格类型下属**解析错误**（`Function 'current_lane' not found in base 'Node'`），整脚本无法编译/加载。`test_solvable.gd` 实例化 `ObstacleSpawner`，故 **S10 硬门禁直接 fail**。 | 改为不标注类型 `var player`，运行期动态分发（FakePlayer/Player 均可）。 |
| **F2** | `entities/pickup_spawner.gd:18` | 致命·编译 | 同上：`var player: Node` + `player.current_lane()`。 | 同上 → `var player`。 |
| **F3** | `entities/obstacle_spawner.gd:20` | 致命·测试 | `var combo: ComboScoring` 但 `test_solvable.gd` 赋 `FakeCombo extends Node`（**非** `ComboScoring` 子类）→ 类型不匹配赋值错误，**`test_solvable.gd` 无法加载**。 | 改为不标注类型 `var combo`。 |
| **F4** | `entities/pickup_spawner.gd:19` | 致命·测试 | 同上：`var combo: ComboScoring` + `FakeCombo` 赋值。 | 同上 → `var combo`。 |
| **F5** | `autoload/save_manager.gd:38` | 中·类型误用 | `js.eval(code, "")` 第二参 `use_global_execution_context` 应为 `bool`，却传空字符串（运行期被强转为 `false`，能跑但有歧义，属红线外但需纠正）。 | 改为 `js.eval(code, false)`。 |
| **F6** | `game.gd:84` + `entities/obstacle_spawner.gd:97` | 中·逻辑/可解性 | 过弯 `force_center()` 把玩家**瞬锁中轨**，但 spawner 仅保证过弯**期间不新生成**中轨 Blocker，无法清除"进入过弯前已在途"的中轨障碍 → 锁中轨期间被既有障碍误杀，**违反 S10 过弯可解性**。 | 新增 `ObstacleSpawner.clear_lane(lane)`；`game.gd` 在 corner-enter 时调用 `obstacle_spawner.clear_lane(1)` 清掉中轨既有 Blocker。 |

修复后的两个 spawner 对 `player`/`combo` 改用动态分发：运行期赋真实 `Player`/`ComboScoring`，单测中赋 `FakePlayer`/`FakeCombo`，均正确；`test_solvable` 的 `spawner.player = fp` / `spawner.combo = fc` / `spawner.lane_system = lane_sys` 三类赋值现全部类型合法。

### 已交叉核对、确认正确的关键点（未改动）
- **class_name 唯一性**：13 个 class_name 互不冲突；3 个 autoload（EventBus/Tuning/InputManager）无 class_name，按 autoload 名引用，符合预期。
- **game.gd ↔ 各模块 API 完全对齐**：SaveManager / AdManager / LaneSystem / CornerController / ComboScoring / ObstacleSpawner / PickupSpawner / Player / HUD 的全部签名、信号、变量名均与契约一致。
- **红线合规**：Player/Game 均不直接读 `InputEvent`（仅 InputManager 读）；模块仅经 EventBus 通信；存档键 `"wasteland_escape_save"`、JS-bridge 用 `Engine.get_singleton("JavaScriptBridge")`（未引用字面类 `JavaScriptBridge`，可跨平台编译）；`AdManager.enabled` 默认 `false`（核心循环零耦合）；`project.godot` 用 `gl_compatibility` / 1280×720 / Web preset。
- **复活计数逻辑正确**：`per_run` 由 `game._per_run_used` 管控，`daily` 存 SaveManager 并跨日重置（ReviveCaps 与 game.gd 双重保险）；`revive_per_run_max=1`/`revive_daily_cap=3` 取 Tuning。
- **相位守卫存在**：`_tick_running` 在 `obstacle_spawner.update` 之后有 `if phase != Phase.RUNNING: return`，避免 game_over 后继续 tick；hit 重入被 `phase==RUNNING && !is_invulnerable()` 与 `o.judged` 双重防住。

---

## (b) 无法在无 Godot 运行时验证的剩余风险

- **B1 解析/编译未真机确认**：所有"能否编译"均为静态推理。建议 CI 跑 `godot --headless --path . --scene <gut>` 实测。
- **B2 主场景缺失**：`project.godot` 的 `run/main_scene="res://scenes/main.tscn"`，但仓库无 `scenes/` 目录。游戏无法从主场景启动；需建 `scenes/main.tscn` 并把 `Game` 节点 + 4 个 autoload 接线（不影响 GUT 单元测试）。
- **B3 GUT 未安装**：无 `addons/gut/`，且缺 `test_runner.tscn`。套件目前无法在任何环境运行；须装 GUT 9.x 并建 runner 注册 Tuning/EventBus/SaveManager/AdManager（README 已记为 CONCERN，非阻塞）。
- **B4 复活测试日期依赖**：`test_revive_caps.test_cross_date_resets_count` 用 `"2026-09-23"` 作 `last_revive_date`，依赖系统日期 `> 2026-09-23`；若 CI 机器日期恰为 `2026-09-23` 或更早，该用例失败（S9 硬门禁红）。建议改用注入式"今日"或固定桩日期，解除系统时钟耦合。
- **B5 复活完整链路无测试**：`game.gd ↔ AdManager ↔ SaveManager` 的端到端复活流程**无任何 GUT 用例**覆盖（仅 `ReviveCaps` 单测）。建议补集成测试：mock `AdManager.enabled=true` 触发死亡 → 验证 `_per_run_used` 与 daily 计数持久化。
- **B6 手感/碰撞无自动化**：跳/二段跳/滑铲/碰撞致死（S2/S3/S4/S6）仅能实机 playtest 复核。
- **B7 引擎版本未钉**：无 `CLAUDE.md` / `docs/engine-reference/<engine>/VERSION.md`；GUT 钉版与导出参数待补（test-plan §1.1 已记）。
- **B8 Web 持久化未实机验证**：`JavaScriptBridge` localStorage 读写路径只能在 HTML5 导出真机走通；headless 走 `_use_memory` 降级分支（已用 `test_save_manager` 覆盖）。
- **B9 性能预算**：draw call ≤50、GC<0.5ms 需 `perf` job 采样，不在 GUT 范围。
- **B10 冗余信号**：`ComboScoring` 与 `game.gd` 都 emit `combo_changed`（多一次），非 bug，可单源化。
- **B11 死代码小瑕疵**：`AdManager.request_revive` 在 revive 不可用时仅 `revive_resolved.emit(false)` 而未 emit `EventBus.revive_declined`，HUD "今日复活已用尽" 文案在该分支不更新；但 `_try_revive` 已先判可用，实际不触发。

---

## (c) GUT headless S1–S12 通过性判断（best-effort）

| 烟雾 | 测试文件 | 修复前 | 修复后（补齐 B3 基建后） |
|---|---|---|---|
| S1 投影 / S5 过弯锁轨 | test_projection / test_lane_system | 绿 | 绿（纯逻辑，无依赖） |
| S8/S11 连击·计分 | test_combo_scoring | 绿 | 绿 |
| **S9 复活上限（硬）** | test_revive_caps | 绿（不依赖 spawner） | 绿，**注意 B4 日期依赖** |
| **S10 可解性（硬）** | test_solvable | **fail**（F1–F4 致脚本无法加载） | 绿（结构保证 + F6 clear_lane 补强） |
| S12 存档降级 | test_save_manager | 绿 | 绿 |

**结构保证（S10）**：单次仅生成单类 Blocker 于单一车道，且生成间距 `SPAWN_INTERVAL=18m` 远大于判定窗 `2·REACH=0.8m` → 任意帧玩家平面至多 1 轨被占 → 至少 2 轨可通行；过弯期间 `corner_active` 跳过中轨生成，配合 F6 `clear_lane(1)` 清除既有中轨障碍，过弯可解性闭环。

**最终判断**：在补齐 GUT addon + `test_runner.tscn`（注册 4 个 autoload）、且 CI 日期非 `2026-09-23` 的前提下，**S1–S12 有较高把握全绿，S9/S10 硬门禁应通过**。但游戏本体仍缺 `scenes/main.tscn`，无法从主场景启动（不影响单元测试）。所有判断均未经真机 Godot 解析确认（B1），建议在 CI 落地后复跑一次 headless 作为最终闸门。

---

## 操作记录（已编辑，未提交 git）
- `entities/obstacle_spawner.gd`：`var player`/`var combo` 去类型化；新增 `clear_lane(lane)`。
- `entities/pickup_spawner.gd`：`var player`/`var combo` 去类型化。
- `autoload/save_manager.gd`：`js.eval(code, "")` → `js.eval(code, false)`。
- `game.gd`：corner-enter 块内新增 `obstacle_spawner.clear_lane(1)`。
- 未改动契约文档、未提交任何 git 操作（按工作流需用户显式审批）。
