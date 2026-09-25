# Sprint 1 计划 ·《WASTELAND ESCAPE / 废土逃生》

> 阶段：Phase 4 收口 → Phase 5 制作 首冲刺（垂直切片）
> 汇编：主理人 游承峰 ｜ 日期：2026-09-24
> 来源：design/ux/ux-spec.md · design/art-bible/asset-spec.md · production/epics/README.md · docs/architecture/test-plan.md · production/vertical-slice.md · autoload/Tuning.gd

## 1. Sprint 目标（一句话）
用最小功能集**实现并跑通垂直切片**，通过 `test-plan.md §3`（S1–S12）与 `vertical-slice.md §3.6` 门禁，在真实手感下验证三支柱 **P1 一指即达 / P2 风险即奖励 / P3 30 秒成长** 成立，而非堆功能。

## 2. 范围

### IN（必须可玩，对应 ⭐ Story）
| 模块 | 切片内含 | 命中 Story | 玩法验收 |
|---|---|---|---|
| 自动前进 | `d += V·dt`，`V=V(d,combo)`，V0=7、封顶 13 | CRL-1/2/3 | 松手也持续前进，速度随距离缓增 |
| 三轨切轨 | lane∈{0,1,2}，左右滑/AD 切轨，平滑插值 | LCS-2/4 | 单指左右滑即切轨，不瞬移 |
| 跳（含二段跳） | 上滑矮跳/按住高跳/空中再上滑二段跳 | LCS-4/5 | 上滑躲地面障，二段跳空中再跳 |
| 滑铲 | 下滑 SLIDE 0.45s，对 Overhead 无敌 | LCS-4/5 | 下滑躲横杆 |
| 单类障碍 | **Blocker（满高 SWITCH-only）** | OBG-4 | 见障必须切空轨，错切=撞=死 |
| 拾取计分 | 独立池 32，当前轨拾取 +1 连击 +10 分 | OBG-2/6、COM-3/4/6 | 收补给即连击+分增长 |
| 过弯锁中轨 | 1 最简弯：强制中轨 + 锁横向 + yaw 旋转；中轨仅 JUMP/SLIDE | LCS-3/6、OBG-7 | 进弯自动回中轨，弯中仍可跳/滑 |
| 死亡结算 | FATAL_HIT→RESULT，写最佳距离/分数 | CRL-1/4/5、PER-1/3/4 | 撞 Blocker 即死，结算显最佳 |
| 一键重开 | RESULT→COUNTDOWN→RUNNING <2s | CRL-5 | 重开不重载场景，对象池复用 |
| 激励视频复活 | 最简 mock Web Provider；上限 **3天/1局** | RAD-1/3/4/5/6 | 看广告回 RUNNING（清障+1s 无敌），上限真触发 |
| 基础 HUD | 距离/分数/连击（只读订阅） | CRL-4、HUD | HUD 不持有状态 |
| Web 运行时 | 切后台暂停 / 音频 resume / 480p 兜底 | CRL-6 | tab blur 不「回来即死」 |

### OUT（延后，见 vertical-slice §2）
Spike/Overhead 正式美术、Gap/Moving/Sequence、同轨贴脸 +2、倍率曲线全开、里程碑 UI、多场景/昼夜、三平台 Provider 全量、粒子特效、完整 Menu/音频终稿、无障碍延展档、异步排行榜。

## 3. Sprint Backlog（按依赖排序）

> 每故事动手前过 `control-manifest.md` 检查项；AC 逐条可测，证据见 GUT 烟雾套件。Owner：工程主程（程基岩）实现 + 自测；设计/美术以占位/灰模先行（asset-spec §5.1）。

| # | 实现步骤 | 命中 Story | 交付物（代码） | 测试门禁 |
|---|---|---|---|---|
| 1 | 伪透视投影 + Tuning 投影参数 + 三轨 + 自动前进 + 基础 HUD | LCS-1/2、CRL-1/2/3、CRL-4 | `core/projection.gd`、`autoload/Tuning.gd`（补 PROJ_*）、`LaneSystem` 雏形、HUD 只读订阅 | S1（投影居中/远处更小）|
| 2 | 跳/二段跳/滑铲 + 单类 Blocker + AABB 碰撞 + 死亡结算 | LCS-4/5、OBG-4/6、CRL-1/4/5 | `Player.gd`（GROUND_RUN/JUMP/DOUBLE_JUMP/SLIDE/CORNER）、`ObstacleSpawner`、碰撞 | S2/S3/S4/S6 |
| 3 | 拾取池 + flank 近失 +1 连击 | OBG-2/6、COM-3/4/6 | 拾取池（32）、`ComboScoring`、近失事件 | S7/S8/S11 |
| 4 | 最简过弯（锁中轨 + yaw）+ 中轨跳/滑障 | LCS-3/6、OBG-7 | `CornerController`、laneLock 协议 | S5 |
| 5 | 存档最佳 + 一键重开 <2s | PER-1/2/3/4/5 | `SaveManager`（wasteland_escape_save）、对象池复用 | S12 |
| 6 | mock 复活链路 + 上限 3天/1局 | RAD-1/3/4/5/6 | `AdManager`（mock Provider）、`core/revive_caps.gd` 纯判定 | S9（R1/R2/R3）|
| 7 | 跑全烟雾套件 + playtest 采样判定 §3.2–3.5 | 全 ⭐ | GUT 套件 + playtest 报告 | S1–S12 全绿 |

## 4. 依赖总图（关键路径）
```
Tuning.gd(真值源, 含 PROJ_*/LaneGeometry) ──► 步骤1–6
EventBus.gd ──► CRL 路由 / COM 近失 / RAD 复活
步骤1(投影+三轨+前进) ──► 步骤2(跳/滑/障/碰撞) ──► 步骤3(拾取/连击)
步骤2 ──► 步骤4(过弯) ; 步骤5(存档) ──► 步骤6(复活计数)
全部 ──► 步骤7(全烟雾+playtest)
```

## 5. Definition of Done（切片通过判据）
`vertical-slice.md §3.6`：**F1–F4 全绿 + P1-1/P1-2 + P2-1 + P3-1/P3-2 + R4-1 实测达成**。
- F1 复活上限强制（每日第4次/本局第2次均拒）；F2/F3 可解性 1000 段非空；F4 一致性红线 grep。
- P1-1 新手 30s 不死率 ≥70%；P1-2 输入延迟 <80ms；P2-1 flank +1 MVP 即触发；P3-1 单局 30–90s、重开 <2s；R4-1 720p 60fps、GC<0.5ms、draw call≤50。
- 任一 F* 不达成 → 切片不通，回对应 Story 修。

## 6. 测试门禁（CI）
- 框架：GUT 9.x（Godot 4.x）；纯逻辑（projection/SpeedModel/LaneSystem/ComboScoring/ReviveCaps/SaveManager）必须 headless 单测。
- 烟雾 S1–S12 每个 PR + nightly；复活上限 S9 为**硬门禁，CI 红即拒**。
- `lint` 校验一致性红线（仅 EventBus 解耦、Player 不读 InputEvent）；`perf` 长局采样 GC/draw call；`export` 校验 gl_compatibility + `.pck<5MB`。

## 7. 已知 CONCERN 与动作项（非阻塞，须跟踪）
| ID | 项 | 负责 | 缓解 |
|---|---|---|---|
| C-A | **Tuning.gd 缺投影参数**：PROJ_focal/horizonY/screenCenterX/camNear/CORNER_yaw/_duration 未落地（C7 校准项） | 工程 | Sprint 步骤1 前补入 Tuning.gd，参数化出图，定标后仅调 Tuning |
| C-B | **Godot 4.x 小版本 + GUT 版本未钉**（缺 CLAUDE.md / engine-reference/VERSION.md） | 主理人 | 补引擎参考文档后钉版；本期以「Godot 4.x + GUT 9.x」假设，不臆造 API |
| C-C | **CORNER laneLock 下发时机** vs 入弯 lead 防「锁中轨却堵死中轨」致死（obstacle-gen §8） | 工程+设计 | 步骤4 联调，S5 单测基于「CORNER_ENTER 即锁」假设验证 |
| C-D | **小程序手势冲突**（横滑切轨 vs 容器返回） | 工程+美术 | 容器层屏蔽横滑返回或改映射；美术强化三轨指示/方向箭头补偿 |
| C-E | **R5 暗调可读性**（玩家珊瑚 vs 危险红同红系） | 美术+工程 | 靠形状差 + 玩家常亮 rim/光环；夜调 playtest 复核 |
| C-F | **相邻轨净空 60px > nearMissBand 24px**，flank 梯度真实性 | 设计+工程 | 常量已落地使公式可验；playtest 量近失带宽 |
| C-G | **COUNTDOWN 独立态 vs RUNNING overlay** | 设计+工程 | 取独立态（core-loop §2.1），非阻塞 |

## 8. 风险与缓解
- **引擎不可运行环境**：本工作区无 Godot 运行时，Sprint 1 产出来源（.gd + GUT 测试）可评审但不可本地跑；门禁验证须在有 Godot 的环境 CI 执行。→ 代码按 ADR 结构落地，CI 配置随引擎参考文档补齐。
- **投影参数漂移**：C-A 用单一真值源 Tuning.gd 收敛，避免美术/代码各写常量。
- **切片范围蔓延**：严格守 §2 OUT 清单，CORE/延展 Story 不进 Sprint 1。
