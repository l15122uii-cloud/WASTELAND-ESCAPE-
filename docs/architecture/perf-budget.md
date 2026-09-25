# R4 性能预算回签 ·《WASTELAND ESCAPE / 废土逃生》

> 回签人：程基岩（engineering-lead）｜ 目标：**60fps@720p（移动端降级 480p）**
> 引擎：Godot 4（Web/HTML5，渲染方法 `gl_compatibility` / WebGL2）
> 说明：本文件评估 GDD 中标注"待程基岩(R4)回签"各项在 Godot Web 下的可达性，并给出**建议回填值**（由主理人协调 design-strategist 回填 GDD，本人不直接改 GDD）。

---

## 1. 世界尺度约定（新增常量，建议回填 GDD）
GDD 混用"米"（速度/间隔）与"世界像素"（近失带），需统一 `PPM`（pixels per meter）：
- **`PPM = 50`**（设计常量，非 GDD 原值）。
- 理由：720p 屏高 720px，玩家 ~1.8m 占 90px；480p 屏高 480px 占 60px，小屏仍可读。
- 派生：720p 屏宽 1280px = **25.6m**；480p 屏宽 854px = **17.1m**。
- 近失带 `nearMissBand=24px` ≈ **0.48m**（贴脸判定带宽，合理）。

---

## 2. 帧预算分解（720p，60fps = 16.67ms）
| 项目 | 预算 | 依据 |
|---|---|---|
| 渲染提交（2D 合批，≤50 draw call） | 4–6 ms | Compatibility + atlas 合批 |
| Process + Physics（玩家运动学 + Spawner + Combo） | 2–3 ms | 障碍数 ≤12，AABB 廉价 |
| GC 尖刺（对象池后） | <0.5 ms | 每帧零分配 |
| HUD 刷新 | 0.5 ms | 仅文本/数值 |
| **余量（尖峰）** | **~6 ms** | 安全垫 |

**结论：720p 稳 60fps 可达，余量充足。** 480p 像素更少更易；移动端 CPU 较慢，建议设 30fps 下限 + 动态分辨率兜底（见 §6）。

---

## 3. R4 待回签项逐项评估

### 3.1 `Vmax = 13 m/s` — ✅ 可达，建议保持
- 每帧位移 = 13 × 50 / 60 ≈ **10.8 px**；障碍宽 >10px，AABB 每帧判**无穿隧**。
- 满 combo 流速加成后 `V_peak = 13 × (1 + 0.001×100) = 14.3 m/s`，仍稳。
- 反应窗口：障碍在 `spawnLookahead` 处出现至到达玩家，720p ≈ 38.4m / 13 = **2.95s** > `reactTime=0.5s`。
- **结论：可达，不改初值。** 移动端 480p 仅靠 PPM 固定即保可读，无需降 Vmax。

### 3.2 `maxLiveObstacles = 12` — ✅ 可达，建议保持（可选降到 10）
- 同屏存活数 ≈ (lookahead + 屏宽 + 回收余量) / 有效最小间距。
- 最大密度（d≥1500m）：`minSpacing = max(intervalMin=8, V·reactTime + obw + buffer) = max(8, 6.5 + 1.5 + 1.5) ≈ 9.5m`。
- 存活行程 ≈ 38.4 + 25.6 + 3 ≈ **67m** → 67 / 9.5 ≈ **7 个，峰值 ≤8**。
- 12 给 **1.5× 余量**，安全；若求更稳可降到 10（仍够）。
- **结论：可达。**

### 3.3 `poolSize = 24` — ✅ 可达，建议保持
- = 2 × `maxLiveObstacles`，标准池余量，避免回收抖动与 GC。
- **补充**：拾取物（金币/星）GDD 未给池容量 → 建议新增 **`pickupPoolSize = 32`**（独立池，不挤占障碍池）。
- **结论：可达。**

### 3.4 `spawnLookahead = 1.5×屏宽` — ✅ 可达，建议保持
- 720p = 38.4m（2.95s 预读）；480p = 25.6m（1.97s）。均 > `reactTime`，且覆盖 ≥2 个 `intervalBase=18m`，保证开局即有可见障碍。
- **结论：可达。**

---

## 4. 美术性能红线对账
| 红线 | 评估 | 结论 |
|---|---|---|
| 单屏 draw call ≤ 50 | 2D 合批 + atlas；视差 2–3 层大图（≤6 call）+ 障碍/玩家/HUD atlas → 估算 15–30 call | ✅ 可达 |
| 同屏粒子 ≤ 120 | `ParticlePool` 硬上限 120，落地/速度线/拾取共享 | ✅ 可达 |
| 贴图 ≤256px 走 atlas | 资源规范，需美术执行 | ✅ 可达（依赖美术） |
| 无实时阴影 | BlobShadow 精灵 | ✅ 可达 |
| 首屏 < 5MB | ⚠️ 见 §5 口径 | ⚠️ 需澄清 |
| 广告 SDK 外部加载 | 外部 `<script>`（平台/中介 CDN），不进 `.pck`；播放时暂停物理 tick | ✅ 零影响（详见 ADR-005） |

### 4.1 三轨伪3D 身后视角对 R4 预算的补充（本次重构）
> 对应 architecture.md §6；玩法由「2D 横版 + 2.5D 视差」重构为「2.5D 伪3D 三轨身后视角」。

- **`PPM=50` 保持不变（设计常量，见 §1）**：世界尺度统一约定，三轨沿用同一 `PPM`；车道横向偏移以像素表达（`laneSpacingPx` = `laneWidthM×PPM` = 100px，入 `Tuning`），**不改动 `PPM` 定义**，亦不改变近失带 `nearMissBand=24px≈0.48m` 的量纲。
- **投影开销可忽略**：伪透视投影为纯数学（`project(x,z)→(sx,sy,scale)`，每障碍仅数次乘法，无矩阵、无 `Node3D`），12 个 live 障碍的投影成本远低于 Process 预算 2–3ms；投影在热路径仍零分配（只写已池化节点的 `position/scale`）。
- **无新增 draw call 类型**：`TrackView` 用单个 `CanvasItem` 自绘伪透视道路 + 车道线（收敛到灭点）= **1 个 draw call**；障碍/拾取 Sprite 共享 atlas 材质合批；即便最坏不合批，全屏仍约 15–30 call，**远优于 ≤50 红线**。
- **过弯零额外开销**：`CornerController.yaw` 仅改 `TrackView`/`BackgroundRoot` 绘制参数，无每帧新分配；对象池策略不变（`poolSize=24` / `pickupPoolSize=32`），GC 尖刺 <0.5ms 不变。
- **结论**：三轨重构对 R4（Vmax=13 / maxLiveObstacles=12 / PPM=50 / draw calls≤50 / `.pck<5MB` / 60fps@720p）**零额外开销**，R4 预算与可达性结论不变；唯一需 playtest 校准的是投影手感参数（`focal`/`horizonY`/`laneSpacingPx`/`camNear`），属可调常量（CONCERN C7，非阻塞）。

---

## 5. 首屏 <5MB 口径澄清与建议（需主理人确认）
- **风险点**：Godot Web 引擎 `.wasm` 约 **30–40MB**（含引擎运行时），不属"游戏资产"。5MB 红线应指**游戏数据/资源 `.pck`**（贴图/音频/场景），而非引擎本身。
- **建议口径**：
  1. 5MB 解释为"首屏可玩**资源包**（.pck 压缩后）"；
  2. 引擎 `.wasm` 经 **CDN + brotli/gzip** 缓存（首访 ~8–12MB，之后浏览器缓存，不计入"首屏可玩"延迟感知）；
  3. 资源措施：全量 atlas、≤256px、`.webp/.ctex` 压缩、用代码 squash-stretch 替代多动画帧、音频短 `ogg`。
- 若 5MB **必须含引擎**，则需评估"引擎分包/延迟加载"或接受首访更大——建议不强行纳入引擎。
- **结论：游戏资源 <5MB 可达；引擎体积需主理人确认是否计入红线口径。**

---

## 6. Web 专项风险与缓解
| 风险 | 缓解 |
|---|---|
| 单线程（pthreads 需 COOP/COEP） | 重逻辑全主线程，帧预算留 ~6ms 余量；禁用 `Thread` |
| 音频自动播放策略 | 首次输入 `AudioServer` resume |
| 切后台（tab blur） | `visibility_changed` 暂停物理 tick，回前台恢复（防"回来即死"） |
| 低端移动掉帧 | 动态分辨率 / 480p 兜底，30fps 下限 |
| GC 抖动 | 对象池（§3.3）+ 热路径零分配 |
| 广告加载/播放 | 请求前暂停物理 tick（RESULT 态本已冻结）；SDK 为外部 JS，不入 Godot 帧循环 → 对 60fps 零持续影响（ADR-005） |

---

## 7. R4 回签汇总表（建议回填 GDD）
| GDD 项 | 初值 | 结论 | 建议回填值 |
|---|---|---|---|
| `Vmax` | 13 m/s | ✅ 可达 | **13（保持）** |
| `maxLiveObstacles` | 12 | ✅ 可达 | **12（或 10 更稳）** |
| `poolSize` | 24 | ✅ 可达 | **24** + 新增 `pickupPoolSize=32` |
| `spawnLookahead` | 1.5×屏宽 | ✅ 可达 | **1.5×屏宽（保持）** |
| 首屏 <5MB | <5MB | ⚠️ 需澄清 | 资源 <5MB；引擎另计（待主理人定口径） |
| `PPM`（世界尺度） | （GDD 无） | 新增 | **50**（建议回填为设计常量） |

---

## 8. GDD "待程基岩(R4)回签" 可达性总判定
- `Vmax=13`：**可达成，不需调初值。**
- `maxLiveObstacles=12`：**可达成。**
- `spawnLookahead=1.5×屏宽`：**可达成。**
- `poolSize=24`：**可达成**；并建议补充拾取物池容量。
- 高 Web 风险项：**无数值项风险高**；唯一需澄清的是首屏 5MB 口径（§5）与新增 `PPM` 常量（§1）。
- 激励视频（P3-ENG-02 补充）：广告 SDK 外部加载，对 `.pck<5MB` 与 60fps@720p 帧预算**零影响**，R4 结论不变；详见 ADR-005。
- 知识缺口：项目缺失 `docs/engine-reference/<engine>/VERSION.md` 与 `CLAUDE.md` 技术偏好，本回签基于 Godot 4 通用知识；建议后续补引擎参考文档以便精确对齐版本号与导出参数。
