# 测试框架建议与烟雾测试清单 ·《WASTELAND ESCAPE / 废土逃生》

> 阶段：Phase 4 预制作（测试框架脚手架规格）｜ 作者：程基岩（engineering-lead-3）
> 配套：architecture.md / adr-001..005 / control-manifest.md / perf-budget.md / production/epics/* / production/vertical-slice.md
> 原则：验证驱动开发——先写测试再实现；纯逻辑模块（投影/速度/连击/复活上限/存档）必须可 headless 单测，不依赖渲染。

---

## 1. 测试框架建议

### 1.1 主推：GUT（Godot Unit Test）addon
- **选型**：`gut`（Atlin Godot Unit Test），Godot 4 适配版（GUT 9.x 系列）。
- **理由**：
  - Godot 生态事实标准，支持 headless（`gut --headless`）与 CI；
  - `assert_eq / assert_almost_eq / assert_true / watch_signals` 覆盖本项目的纯逻辑断言；
  - 可挂在测试场景加载 Autoload（Tuning/EventBus/SaveManager/AdManager）做集成测试；
  - 支持 `prerun`/`postrun` 钩子，便于每条 Story 跑后回收对象池（守 R4 零分配）。
- **安装**：作为 `addons/gut/` 加入工程（不进首屏 `.pck` 资源统计，仅开发期；导出时剔除）。
- **知识缺口（⚠️ 待主理人补 `docs/engine-reference/<engine>/VERSION.md` 与 `CLAUDE.md`）**：当前未锁定 Godot 4 具体小版本（4.2/4.3/4.4？），GUT 版本须对齐。建议补引擎参考文档后钉定；本期以「Godot 4.x + GUT 9.x」为脚手架假设，不臆造 API。

### 1.2 备选：Godot 内置 `--headless` + 自写轻量断言器
- 若不愿引入 addon：用 `MainLoop` 测试脚本 + `@tool` 脚本在 Editor 跑；但无信号监听/断言库，维护成本高，**不推荐**作为主框架，仅作最小冒烟兜底。

### 1.3 性能测试（非单测）
- 帧预算用 Godot 内置 **Profiler / 自定义 `Performance` 采样**（`perf-budget.md §2`）：渲染提交/Process+Physics/GC 尖刺；CI 里跑一段长局采样峰值，断言 GC 尖刺 <0.5ms、draw call ≤50（用 `RenderingServer.get_rendering_info` 或 `get_draw_calls`）。
- 性能测试不放 GUT 单测（耗时、抖动大），单独 `scripts/perf_smoke.gd` 在 CI `perf` job 跑。

---

## 2. 测试分层策略
| 层 | 对象 | 是否 headless | 工具 | 频率 |
|---|---|---|---|---|
| 单元（纯逻辑） | projection / SpeedModel / LaneSystem 数学 / ComboScoring / ReviveCaps / SaveManager 逻辑 | ✅ 是 | GUT | 每个 PR |
| 集成（EventBus） | CoreLoop 路由 / 近失→连击 / 死亡→结算 | ✅ 是（用测试场景挂 Autoload） | GUT | 每个 PR |
| 烟雾（玩法） | 切轨/跳/二段跳/铲/过弯锁轨/碰撞/计分/连击/复活上限 | ✅ 是（模拟输入，无真人） | GUT 烟雾套件 | 每个 PR + nightly |
| 视觉/手感 | 投影可读性/过弯 yaw 手感 | ❌ 需 playtest | 人工 | playtest |
| 性能 | 帧预算/draw call/GC | ✅ 是（采样） | perf_smoke | CI perf job |

---

## 3. 核心循环烟雾测试清单（强制覆盖）
> 每条对应 production/epics 中 Story 的 AC；「**硬**」= 架构/策划锁定的不可妥协项（复活上限 3天/1局）。

| # | 烟雾用例 | 验证点 | 命中 Story | 关键断言 |
|---|---|---|---|---|
| S1 | **切轨** | 相邻轨切换 + 边界夹取 | LCS-2 | `switch_lane(-1)` 从 lane2→lane1→lane0，不越界；插值 0.1–0.15s 到位 |
| S2 | **跳** | 矮跳/高跳 | LCS-5 | 上滑→y 升起回落 GROUND；按住→y 峰值更高（vJumpHigh>vJumpLow） |
| S3 | **二段跳** | 空中再跳 | LCS-5 | 空中再上滑→二次上升；落地回 GROUND；速度低于高跳（防失控） |
| S4 | **滑铲** | 滑铲无敌帧 | LCS-5/OBG-4 | 下滑→SLIDE 态 0.45s；期间 Overhead 不致死，Blocker 仍致死 |
| S5 | **过弯锁轨** | CORNER 强制中轨 + 锁横向输入 | LCS-3/6 | `CORNER_ENTER`→ current_lane 收敛 lane1；锁期间 LANE_LEFT 无效；JUMP/SLIDE 仍生效 |
| S6 | **碰撞** | AABB 致死 | OBG-4/6 | 真实碰撞 Blocker→FATAL_HIT→RESULT；近失（未碰撞）不致死 |
| S7 | **计分** | V·dt·m 累加 | CRL-3/COM-4 | 每帧 score 增 `≈V·dt·m`；m 来自当前 combo |
| S8 | **连击** | 衰减/跨轨不中断 | COM-1/2/5 | 无事件 >T(2.5s)→清零；连续切轨不中断 combo |
| S9 | **复活上限（硬）** | 每日≤3 + 每局≤1 | RAD-3/6 | 见 §5 强制用例 R1/R2 |
| S10 | **可解性（硬）** | 任意 Z 至少一轨可通行 | OBG-5 | 随机 1000 段断言「可达轨集合非空」 |
| S11 | **近失（flank）** | 相邻轨掠过 +1 | OBG-6/COM-6 | 相邻轨障碍掠过→combo+1、score+（MVP 即触发） |
| S12 | **存档降级** | localStorage 失败不阻塞 | PER-1/2 | 隐私模式抛错→内存字典，游戏继续 |

> 注：S9 复活上限为策划/架构**锁定值**（`revive_daily_cap=3`、`revive_per_run_max=1`，core-loop §6.1 / ADR-005 §9），任何实现 PR 必须带该用例且 **CI 红即拒**。

---

## 4. CI 建议
- **平台**：GitHub Actions（或等价）。
- **Jobs**：
  1. `lint`：`grep` 校验一致性红线（control-manifest §B）——模块间仅经 EventBus、Player 不读 `InputEvent`、速度模型/近失带仅单处定义；`npm run lint`（若引入 GDScript 静态检查如 `gdlint`/`gdformat`）。
  2. `test`：headless 跑 GUT 单元+集成+烟雾套件（§3 全量）；失败即红。
  3. `perf`（nightly/按需）：长局采样帧预算，断言 GC<0.5ms、draw call≤50。
  4. `export`（按需）：Web export preset 校验 `gl_compatibility`、`.pck<5MB`（资源，引擎另计 CDN）。
- **缓存**：Godot 二进制与 `.wasm` 走 CDN/brotli 缓存；测试不依赖网络广告 SDK（Provider 用 mock，ADR-005 降级路径）。
- **门禁**：`test` 全绿 + 复活上限用例(S9)通过，方可合入 Phase 4 实现 PR。

---

## 5. 最小冒烟测试脚手架示例（Godot 工程内）
> 说明：以下为**脚手架**——给出目录结构与关键断言/代码，纯逻辑可 headless 跑；实际跑通需补 GUT addon + 测试场景。引擎版本未钉（见 §1.1 知识缺口），API 不臆造。

### 5.1 目录结构
```
res://
├── addons/gut/                  # GUT addon（测试期引入，导出剔除）
├── tests/
│   ├── test_projection.gd       # LCS-1 投影纯数学
│   ├── test_lane_system.gd      # LCS-2/3 切轨 + 输入锁
│   ├── test_revive_caps.gd      # RAD-3/6 复活上限【硬】
│   ├── test_save_manager.gd     # PER-1/2/5 存档 + 降级
│   ├── test_combo_scoring.gd    # COM-1/2/3 连击 + 衰减 + flank
│   └── test_solvable.gd         # OBG-5 可解性 1000 段【硬】
├── core/revive_caps.gd          # ★纯逻辑复活上限判定（可单测，无需场景树）
└── test_runner.tscn             # 挂 Autoload(Tuning/EventBus/SaveManager/AdManager)+GUT
```

### 5.2 关键断言示例（GDScript / GUT）
```gdscript
# tests/test_projection.gd  — LCS-1
extends GutTest
func test_project_farther_is_smaller():
    var near = Projection.project(0.0, 5.0)
    var far  = Projection.project(0.0, 50.0)
    assert_true(far.scale < near.scale, "z 越大 scale 越小")
    assert_almost_eq(near.screenX, Tuning.PROJ_screenCenterX, 0.001, "中轨 worldX=0 屏幕居中")

# tests/test_lane_system.gd  — LCS-2/3（过弯锁轨 S5）
func test_corner_locks_lateral_input():
    var lane = LaneSystem.new(); lane.current_lane = 2
    lane.force_center(); lane.set_input_locked(true)
    lane.update(0.1)                      # 插值回中轨
    lane.on_lane(-1)                      # 锁期间忽略
    assert_eq(lane.current_lane, 1, "锁中轨后切左无效，仍为 lane1")
    assert_true(lane.is_input_locked(), "横向输入锁生效")

# tests/test_revive_caps.gd  — RAD-3/6【硬：S9 复活上限】
func test_daily_cap_is_3():
    var caps = ReviveCaps.new()
    # 当日已到账 3 次
    var st = { "revive_count_today": 3, "last_revive_date": "2026-09-24", "per_run_used": 0 }
    assert_false(caps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
                 "每日第 4 次请求必须被拒（daily_cap=3）")

func test_per_run_cap_is_1():
    var caps = ReviveCaps.new()
    var st = { "revive_count_today": 0, "last_revive_date": "2026-09-24", "per_run_used": 1 }
    assert_false(caps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
                 "本局已复活 1 次后再死亡不再提供（per_run_max=1）")

func test_same_day_reset_cross_date():
    var caps = ReviveCaps.new()
    var st = { "revive_count_today": 3, "last_revive_date": "2026-09-23", "per_run_used": 0 }
    assert_true(caps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
                "跨日后计数重置，第 1 次可用")

# tests/test_solvable.gd  — OBG-5【硬：S10 可解性】
func test_any_z_has_passable_lane():
    var gen = ObstacleSpawner.new()
    for i in 1000:
        var seg = gen.generate_segment(randf() * 2000.0, "MVP")
        assert_true(gen.has_passable_lane(seg), "段 %d 至少一轨可通行" % i)
        assert_true(gen.reachability_nonempty(seg), "段 %d 可达轨集合非空" % i)
```

### 5.3 ReviveCaps 纯逻辑（建议新增，便于单测）
```gdscript
# core/revive_caps.gd  — 不含 Node，纯判定，供 AdManager 调用，可 headless 单测
class_name ReviveCaps
static func is_revive_available(state: Dictionary, daily_cap: int, per_run_max: int) -> bool:
    if state.get("per_run_used", 0) >= per_run_max: return false
    if state.get("last_revive_date") != _today():     # 跨日
        state["revive_count_today"] = 0
        state["last_revive_date"] = _today()
    if state.get("revive_count_today", 0) >= daily_cap: return false
    return true
static func _today() -> String:                       # 由 SaveManager 注入日期戳
    return OS.get_date_string_from_system()           # 仅日期，无时区风险（Web 单线程）
```

---

## 6. 知识缺口与待确认（回传主理人）
1. **引擎小版本未钉**（perf-budget §8 已记）：无 `CLAUDE.md` / `docs/engine-reference/<engine>/VERSION.md` → GUT 钉版与导出参数待补引擎参考文档后确认。
2. **相邻轨横向净空 60px > nearMissBand 24px**：flank 是否恒 +1 取决于 playtest（architecture §6.5 CONCERN）；测试断言「flank 触发 +1」成立，但「梯度真实无主导策略」需人工 playtest。
3. **切片 Provider**：RAD-2 三平台 Provider 在切片用 mock Web Provider；小程序/TapTap Provider 与 CMP 方案待发行渠道定（CONCERN C6）。
4. **CORNER 弯道窗口协议时序**（obstacle-gen §8 CONCERN）：S5 过弯锁轨单测基于「CORNER_ENTER 即锁」假设，须与 CoreLoop/ObstacleSpawner 联调确认 laneLock 下发时机。
