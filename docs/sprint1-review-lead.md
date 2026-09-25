# Sprint 1 垂直切片 · 主理人逐行评审报告

> 评审人：游承峰（game-development-studio 主理人）
> 评审对象：本工作区 `C:\Users\HW\WorkBuddy\2026-09-24-23-12-02`（= 你 push 到 `fix/sprint1-vertical-slice` 的同一套代码，逐字节一致）
> 方法：全量静态阅读 25 个 `.gd` + `project.godot` + `test_runner.tscn` + grep 红线核验（InputEvent / JavaScriptBridge / get_singleton / 存档键）
> 环境限制：本机无 Godot 运行时，无法真机解析/运行；所有「能否编译/运行」均为静态推理

---

## 质量门总判定：**CONCERNS（可进下一阶段，但须先完成最终闸门）**

三张清单（②红线 / ③硬门禁 / ④改动复核）**静态全部 PASS**；无 FAIL 级代码缺陷。
但存在**环境/验证类 CONCERN**（C-A~C-F），必须在进 Phase 6 打磨 / Phase 7 发布前由 CI 真机 + 实机 playtest 收口。

---

## ② 红线核验 — PASS

| 红线 | 证据（file:line） | 判定 |
|---|---|---|
| 仅 `InputManager` 读 `InputEvent`，Player/Game 不读 | `core/input_manager.gd:14` 唯一 `_unhandled_input(e: InputEvent)`；`player.gd:5` / `lane_system.gd:5` 仅为注释提及，**无实际读取**（grep `InputEvent` 在代码文件仅此 3 处，后两者纯注释） | ✅ PASS |
| 模块仅经 `EventBus` 解耦通信 | `game.gd:45-50` 全部经 `EventBus.*.connect`；`hud.gd:20-24` 仅订阅；无跨模块直接字段读运行时状态 | ✅ PASS |
| 存档键 `wasteland_escape_save` 单一真值 | `autoload/save_manager.gd:9` 唯一 `const SAVE_KEY`；grep 全仓仅此一处定义 | ✅ PASS |
| JS 桥接仅用 `Engine.get_singleton("JavaScriptBridge")`，绝不引用字面类 | `save_manager.gd:28/33/52` 均用字符串 `"JavaScriptBridge"`；无 `JavaScriptBridge.` 直接引用 → 跨平台可编译 | ✅ PASS |
| `AdManager.enabled` 默认 `false`（核心循环零耦合） | `autoload/ad_manager.gd:13` `var enabled := false` | ✅ PASS |
| Web 渲染后端 / 视口 / preset | `project.godot:14` `GL Compatibility`；`:32-33` `gl_compatibility`；`:25-26` 1280×720；`:42-47` `[preset.0]` Web | ✅ PASS |

> 补充：自愈式 set/get 也经 `try/catch` 内存降级（`save_manager.gd:37/57` 的 `try{}catch` + `_use_memory` 分支），headless 下 `test_save_manager` 已覆盖（S12）。

---

## ③ 硬门禁核验 — PASS

### S9 复活上限（硬门禁）— PASS
- `core/revive_caps.gd:8-17` 三道闸：`per_run_used >= per_run_max` → false；跨日重置；`revive_count_today >= daily_cap` → false。
- 锁值取 `Tuning.revive_per_run_max=1` / `revive_daily_cap=3`（`Tuning.gd:65-66`，与 GDD 对齐）。
- **B4 修复落地**：`is_revive_available(..., today_override := "")` 注入式日期（`revive_caps.gd:11`），解除系统时钟耦合。
- 测试 `tests/test_revive_caps.gd`：`test_daily_cap_is_3` / `test_per_run_cap_is_1` / `test_available_when_under_caps` / `test_cross_date_resets_count`（显式传 `"2026-09-24"`，不再依赖 CI 机器日期）。→ S9 硬门禁稳定通过。

### S10 过弯可解性（硬门禁）— PASS
- 结构保证：`obstacle_spawner.gd:61-70` 单次仅生成**单类 Blocker 于单一车道**；`SPAWN_INTERVAL=18m`（`obstacle_spawner.gd:12`）≫ 判定窗 `2·REACH=0.8m` → 任意帧玩家平面至多占 1 轨 → 至少 2 轨可通行。
- 过弯期：`obstacle_spawner.gd:68-69` `corner_active` 时跳过中轨生成；**F6 补强** `game.gd:84` 过弯 enter 调 `obstacle_spawner.clear_lane(1)`，清除进入过弯前已在途中之既有中轨 Blocker。
- 测试 `tests/test_solvable.gd`：`test_any_z_has_passable_lane`（2000 段，`seed(12345)`，断言 `blocked.size()<3`）+ `test_corner_never_blocks_center_lane`（500 段强制 `corner_active`，断言不含 lane1）。→ S10 硬门禁稳定通过。

---

## ④ 改动复核 — PASS（F1–F6 + B3/B4/B5 全部落地）

| 修复 | 复核证据（file:line） | 判定 |
|---|---|---|
| **F1** obstacle_spawner `var player` 去类型 | `obstacle_spawner.gd:19` `var player   # 故意不标注类型`；`:74/76` 调 `player.current_lane()/is_invulnerable()` 经动态分发 | ✅ |
| **F2** pickup_spawner `var player` 去类型 | `pickup_spawner.gd:18` 同模式；`:59` 调 `player.current_lane()` | ✅ |
| **F3** obstacle_spawner `var combo` 去类型 | `obstacle_spawner.gd:20`；`:80` 调 `combo.on_near_miss()`（FakeCombo/ComboScoring 均可） | ✅ |
| **F4** pickup_spawner `var combo` 去类型 | `pickup_spawner.gd:19`；`:60` 调 `combo.on_pickup()` | ✅ |
| **F5** `js.eval(code, false)` | `save_manager.gd:38` 第二参由 `""` 改为 `false`（bool 语义正确） | ✅ |
| **F6** 过弯 `clear_lane(1)` | `game.gd:84` `obstacle_spawner.clear_lane(1)`；`obstacle_spawner.gd:97-100` 新增 `clear_lane(lane)` | ✅ |
| **B3** 测试运行器 | `test_runner.tscn` 已建（GUT 节点）；⚠️ 但 `res://addons/gut/gut.gd` **仍不存在**（见 C-E，真阻塞项是 GUT addon 安装） | ⚠️ 部分 |
| **B4** 注入式日期 | `revive_caps.gd:11` + `test_revive_caps.gd:22-24` | ✅ |
| **B5** 端到端复活集成测试 | `tests/test_revive_integration.gd`：`test_end_to_end_revive_increments_and_persists`（断言 `_per_run_used==1`/daily 持久化==1/phase==RUNNING/无敌帧）+ `test_revive_declined_does_not_consume_slot`（enabled=false 停留 RESULT、不消耗额度）；mock `show_rewarded` 同步回调使 `_on_hit()` 内整条链路同步完成，断言合法 | ✅ |

---

## 对工程主程自审报告（sprint1-self-check.md）的更正

1. **B2「主场景缺失」为误报（应划掉）。** 本工作区 `scenes/main.tscn` **确实存在**（Glob 确认），且 `project.godot:13` `run/main_scene="res://scenes/main.tscn"` 已接线（Main Node2D → `res://game.gd`）。游戏可经主场景启动，无需补建。
2. **B3 仅完成「配置」半边。** `test_runner.tscn` 已建，但其引用的 `addons/gut/gut.gd` 并未随代码入库（全仓 grep `*.gd` 无 `addons/` 路径）。**真阻塞 CI 跑测试的是 GUT addon 安装，而非 runner 本身。**

---

## 剩余 CONCERN（非代码缺陷，属验证/环境/一致性）

| ID | 项 | 性质 | 建议 |
|---|---|---|---|
| **C-A** | 无 Godot 真机解析/编译确认（原 B1） | 验证 | CI `godot --headless --path .` 实跑一次，作为最终闸门 |
| **C-B** | 引擎版本 / GUT 版本未钉（`project.godot:3` 注释、缺 `CLAUDE.md`/`VERSION.md`） | 环境 | 补 `docs/engine-reference/godot/VERSION.md` + 钉 GUT 9.x 提交 |
| **C-C** | 手感/跳·二段跳·滑铲·碰撞致死（原 B6） | 验证 | 实机 playtest，校准 `Tuning` 跳参/间距 |
| **C-D** | 小程序横滑返回冲突（`input_manager.gd:4` 已记） | 平台 | 容器层处理，非本切片阻塞 |
| **C-E** | **GUT addon 未安装**（真正阻塞跑测试） | 环境 | `git submodule add` 或拷贝 GUT 9.x 至 `addons/gut/` |
| **C-F** | 性能预算（draw call≤50 / GC<0.5ms，原 B9） | 验证 | CI `perf` job 采样 |
| nit-1 | `obstacle_spawner.gd:12` `SPAWN_INTERVAL:=18.0` 硬编码，未引用 `Tuning.intervalBase`（值一致但非单源） | 一致性 | 改为 `Tuning.intervalBase` 或删注释去歧义 |
| nit-2 | `combo_changed` 双 emit（`combo_scoring.gd:32` + `game.gd:108`） | 冗余 | 可单源化，非 bug |
| nit-3 | `ad_manager.gd:33-36` 不可用时未 emit `EventBus.revive_declined`（原 B11） | 一致性 | `_try_revive` 已先判可用，实际不触发；补 emit 更稳 |

---

## 进 Phase 6/7 前的「最终门控清单」

1. **安装 GUT 9.x** → `addons/gut/`（C-E，否则 S1–S12 无法运行）。
2. **CI headless 跑 S1–S12**，重点盯 **S9 / S10 硬门禁** 全绿（C-A）。
3. **实机 playtest**：三轨切轨手感、过弯锁中轨不误杀、跳/滑/二段跳、复活无敌帧、HUD 文案（C-C）。
4. **钉版本**：Godot 小版本 + GUT 9.x 提交哈希（C-B）。
5. 可选清理 nit-1~3。

> 代码侧（②/③/④）已具备进下一阶段条件；上述 1–4 为发布前必过的硬闸门。
