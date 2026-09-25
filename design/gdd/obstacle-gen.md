# 障碍生成系统 GDD · 《WASTELAND ESCAPE / 废土逃生》

> 系统名：Obstacle Generation（障碍生成）｜ 阶段：Phase 2 系统设计（三轨变体重构）｜ 评审强度：lean
> 依赖决策：D1 黄昏/夜晚 / D2 2.5D 伪3D 三轨背后视角 / D3 单指滑动操作 / D4 单局无限距离
> 服务支柱：**P2 风险即奖励（主打：近失接入点）** / P3 30 秒成长（平滑难度、动作分层） / P1 一指即达（高可读性）
> 重构注记：本文件为「2D 横版单线」→「2.5D 三轨背后视角」变体。确定性 RNG、分层门控保留；生成单位由"单线障碍"改为"三轨分段（segment）分别布置"；新增**三轨可解性硬约束（不可全堵 + 横向可达性）**与**过弯段（CORNER）中轨锁定约束**。

---

## 1. 概述与目标
- **定位**：无限、公平、可解且随距离升级的三轨障碍流生成器；同时是 P2 的"风险供给方"——发射近失事件，让贴脸有回报通路；并保证**始终存在可通行解**。
- **对齐支柱**：
  - **P2（风险即奖励）**：生成器为每个障碍天然提供"安全余量线"与"贴脸近失线"——同轨擦过（高风险高回报，贴脸 +2）与相邻轨掠过（低风险 +1）并存；近失失败=真实碰撞=死亡，代价真实。
  - **P3（成长感）**：速度随距离缓增 + 密度缓增，匹配熟练度；动作集门控保证 MVP 不被不可解障碍劝退。
  - **P1（一指即达）**：障碍用"形状+亮度"双编码（锐角红=危险），高速下瞬间可辨（呼应美术圣经可读性红线）。
- **三轨核心**：每条 segment 对三条轨（左/中/右）**分别**布置障碍/收集物；硬约束——**任意 Z 至少留一条可通行轨**且玩家**横向可达**该轨；过弯锁定中轨期间仅中轨生成跳/滑可解障碍。
- **解决的玩家问题**：让无尽关卡因"公平可解"而心流不断；让风险路线可被系统识别并奖励。
- **主题换皮（丧尸末日）**：障碍/收集已按美术圣经丧尸向重命名（钢筋尖刺/丧尸爪、断梁、裂墙、游荡丧尸、补给/急救包），**危险语义（锐角+脉动+警示红）不变**，核心动作与生成逻辑完全不变（详见 §2.2 与美术圣经）。

## 2. 核心机制
### 2.1 生成调度（确定性 RNG，三轨 segment 化）
- 用**距离种子 RNG**（seed 由距离段派生）保证同进度可复现/公平，便于里程碑与复核。
- Track 切分为**段 `segment`**（长度 `segLen`，初值 30m）。每段对左/中/右三轨**独立**布置障碍/收集物；段内每轨障碍纵向间隔 ≥ `minSpacing`（纵向反应空间）。
- 调度器按 `tier` + 难度从"模式库 pattern library"抽取，或程序化填充三轨并跑可解性校验（见 §2.3）。
```
interval(d) = max(intervalBase, intervalBase - (intervalBase-intervalBase)·clamp(d/dFull,0,1)) + jitter(±jitterAmt)
minSpacing  = V·reactTime + obstacleWidth + buffer      // 纵向反应空间（同原 2D）
// 三轨新增：横向可达性约束
laneSwitchLead = V·laneSwitchTime + laneBuffer           // 切轨所需前瞻，保证"封堵轨"前存在合法切入轨
```
- 段内每轨障碍 x 位置 = 该轨最右障碍 x + max(minSpacing, interval(d))。

### 2.2 障碍类型与所需动作（三轨语义 + 动作集门控）
| 类型 | 形状(美术) | 所在轨 | 所需动作 | tier 门控 |
|---|---|---|---|---|
| 钢筋尖刺/丧尸爪 Spike | 三角红（地面） | 单轨 L/C/R | JUMP 或 SWITCH | MVP |
| 断梁/横杆 Overhead | 红横杆（高处） | 单轨 L/C/R | SLIDE 或 SWITCH | MVP |
| 残骸路障/裂墙 Blocker | 锐角红块（满高，含残破建筑面） | 单轨 L/C/R | SWITCH only（不可跳/滑） | MVP |
| 坍塌缺口 Gap | 地面断口 | 单轨 L/C/R | JUMP（时机） | 核心 |
| 游荡丧尸/翻倒车 Moving | 红横移块（跨轨摆动） | 动态（跨轨） | 时机/切轨 | 核心 |
| 丧尸潮/连环坍塌 Sequence | 红序列（错落三轨） | 三轨错落 | 连续切轨（模式） | 核心 |

- **三轨风险即奖励示例（呼应 P2）**：
  - 「中轨矮障→滑铲」：中轨 Overhead，留中轨滑过（同轨擦过 +1）或切左右（相邻轨掠过 +1）——两种低风险选择。
  - 「左轨高障→跳或切右」：左轨 Spike，**同轨跳**赌贴脸(+2) 或 **切右轨**收掠过(+1)——高风险高回报 vs 低风险低回报的真实权衡。
  - 「三轨错落需连续切轨」：Sequence 模式，强制在 Z 序列中连续切轨穿针，每处相邻轨掠过 +1，漏切=撞=死。
- **可解性硬约束**：见 §2.3。MVP 绝不生成 Gap/Moving/Sequence（所需动作不在 MVP 动作集），杜绝不可解关。

### 2.3 可解性硬约束（≥1 可通行轨 + 横向可达性）
- **不可全堵死**：对任意 Z（以障碍分辨率采样），被封堵的轨集合 `B(Z)` 不得等于 {L,C,R} 全集——必须至少留一条可通行轨。
  - "可通行轨"定义：该轨在 Z 处为空，或仅含 JUMP/SLIDE 可解障碍（Spike/Overhead/Gap 该类），不含 Blocker/Moving（须切轨才能过）。
- **横向可达性（三轨特有）**：玩家当前轨若被封堵，必须能在到达该 Z 前切入某可通行轨；切轨一次移动一条相邻轨，且不能"穿越"被封堵轨。
  - 形式化：维护前向可达轨集合 `A(z)`，由玩家当前轨按"每 `laneSwitchLead` 距离可切换一条相邻轨（且不经过封堵轨）"递推；要求对任意 Z 存在 `l∈A(Z)∩Passable(Z)`。生成时若校验失败 → 回退该段为更松模式 / 强制插入中轨缺口窗口，保证存在合法穿行路径。
  - 此即三轨版 `minSpacing` 等价物：纵向反应空间 + 横向切轨时间共同保证可解。
- **相邻轨净空（几何）**：相邻轨横向净空 = `laneSpacingPx − playerHalfWidthPx − obstacleHalfWidthPx`，应落在 `nearMissBand` 内（见 §8 / combo §8）使相邻轨掠过恒触发近失 +1；若 > band 则仅安全通过无奖励（需 LaneGeometry 常量落地后复核）。

### 2.4 近失检测与事件发射（P2 接入点，三轨语义）
- 障碍越过玩家判定面瞬间，结算玩家壳与该障碍壳**最小净空 `d`**（世界像素）：
  - **同轨障碍**（Spike/Gap 跳越、Overhead 滑过）：`d` = 纵向/垂直擦过净空 → `0<d≤band` 触发 `NEAR_MISS(graze)`；`d≤tier` 为贴脸(+2)。
  - **相邻轨障碍**：`d` = 横向掠过净空（几何常量）→ `0<d≤band` 触发 `NEAR_MISS(flank)`（+1，低风险）。
- **碰撞优先级高于近失**：先判碰撞（AABB 精确），未碰撞才判近失，防误判。
- **安全路线天然存在**：玩家以充裕余量通过（d 远大于 band）即安全但无近失奖励；贴脸（d 落入 band）高回报但更易落碰撞。真实权衡。

### 2.5 过弯段（CORNER）约束
- **CORNER 段标记**：由 CoreLoop/赛道提供弯道窗口（告知 obstacle-gen 该段 `laneLock=center`）。过弯时输入锁定中轨（左右滑失效，见 core-loop §3 / control-manifest，待对齐）。
- **生成约束**：CORNER 段仅在**中轨**生成障碍，且仅为 JUMP/SLIDE 可解类型（Spike/Overhead，核心档可加 Gap），**绝不生成需横向切轨的障碍**（Blocker/Moving/Sequence 跨轨）。保证"锁定中轨"期间仍可跳/滑通过、无穿隧。
- **入弯引导**：CORNER 段前须预留足够 lead（≥ `laneSwitchLead`）让玩家切回中轨；弯前最后可解窗口不封堵中轨。

### 2.6 二段跳窗口（核心档）
- Gap 宽度按当前 `V` 与二段跳可达距离约束，保证可达（核心档启用二段跳后）。

## 3. 输入与控制（基于 D3）
- **生成器本身无玩家输入**——自主调度。玩家输入由 CoreLoop 处理（见其 GDD §3）。
- 生成器仅读取 `tier`（MVP/核心）与 `laneLock`（CORNER 时=center）做门控，确保发出的障碍"当前动作集一定可解"且"弯道不堵中轨"，保护 P1 最低门槛。

## 4. 关键数值与参数初值
| 变量 | 含义 | 初值 | 单位 | 备注 |
|---|---|---|---|---|
| `PPM` | 世界尺度（像素/米） | 50 | px/m | 米↔世界像素换算基准；`nearMissBand=24px≈0.48m`、`Vmax` 每帧位移≈10.8px 均以此派生（与 core-loop 同一真值） |
| `intervalBase` | 起始平均间隔 | 18 | m | d=0 附近 |
| `intervalMin` | 最小平均间隔 | 8 | m | 远距离密度上限 |
| `dFull` | 达到最小间隔的距离 | 1500 | m | 难度爬升全长 |
| `jitterAmt` | 间隔抖动 | 3 | m | 防机械感 |
| `reactTime` | 反应时间基准 | 0.5 | s | 最小间隔依据 |
| `buffer` | 间隔安全缓冲 | 1.5 | m | — |
| `segLen` | 段长度 | 30 | m | **三轨新增**：三轨分别布置的基本单位 |
| `laneSwitchTime` | 切轨耗时 | 0.18 | s | **三轨新增**（初值，待 core-loop 确认）；`laneSwitchLead=V·0.18+laneBuffer` |
| `laneBuffer` | 切轨安全缓冲 | 1.0 | m | **三轨新增** |
| `nearMissBand` | 近失外缘（供连击） | 24 | px(世界) | **单一事实源**（三轨下=壳间最小净空：同轨擦过/相邻轨掠过共用；≈0.48m @ PPM=50） |
| `nearMissTier` | 贴脸分层阈值 | 12 | px | **单一事实源**（与 combo-scoring 共用真值） |
| `maxLiveObstacles` | 同屏障碍上限 | 12 | 个 | **R4 已回签**（三轨下为**全局存活障碍上限**，跨三轨合计，不按轨拆分；可选降到 10 更稳） |
| `spawnLookahead` | 前方生成预读 | 1.5×屏宽 | — | **R4 已回签** |
| `poolSize` | 障碍对象池容量 | 24 | — | **R4 已回签**（对象池复用防 GC） |
| `pickupPoolSize` | 拾取物独立对象池 | 32 | — | 补给/急救包走独立池，不挤占障碍池 `poolSize`（见 combo-scoring §4） |

> `nearMissBand/Tier` 与 combo-scoring 为**同一真值**，仅在本系统定义、连击系统引用，避免跨 GDD 数值漂移（一致性红线）。`PPM` 世界尺度常量与 core-loop 共用同一真值。`maxLiveObstacles`/`poolSize`/`pickupPoolSize` 为 R4 已回签事实源，三轨仅改变障碍的轨分布，不改变全局 live/池上限。首屏包体口径：游戏资源 `.pck` <5MB，引擎 `.wasm` 经 CDN 缓存另计。
> **待补常量（跨 GDD，见 §8）**：`laneSpacingPx` / `playerHalfWidthPx` / `obstacleHalfWidthPx`（LaneGeometry）尚未定义，影响相邻轨净空与横向可达性校验。

## 5. 边界与失败处理
- **不可解防护**：§2.3 可解性硬约束（不可全堵 + 横向可达性校验）+ 动作集门控 + `minSpacing` 强制，任何 `tier` 下不生成"当前动作不可通过"的障碍组合。
- **重叠/堆叠防护**：每轨内下一障碍 x ≥ 该轨最右障碍 x + minSpacing；跨轨无重叠（不同轨独立布置）。
- **碰撞 vs 近失优先级**：先判碰撞（AABB 精确），未碰撞才判近失，防误判。
- **性能**：对象池上限 `poolSize`/`maxLiveObstacles` 回收复用；超出则停止生成直到回收（**R4 已回签**：poolSize=24、maxLiveObstacles=12 可达，可选降到 10 更稳）。
- **确定性**：RNG 由距离段派生，保证里程碑公平与可复核；不依赖每帧随机导致不可复现。
- **边缘情况**：极端高速（`Vmax`）下 `minSpacing` 与 `laneSwitchLead` 自动放大，仍保证反应/切轨空间；首障碍在玩家前方固定安全距离生成，避免开局即死；CORNER 段若 `laneLock` 标记错误/缺失，回退为该段仅中轨 Spike/Overhead，防止"锁定中轨却堵死中轨"的致死漏洞。

## 6. 与其他系统的耦合
| 接口 | 方向 | 内容 |
|---|---|---|
| CoreLoop → ObstacleGen | 调用+供参 | `update(dt, V, d, tier, laneLock)`；提供 `V`（速度真值）、`d`、`tier`，及 CORNER 段的 `laneLock=center` 信号 |
| ObstacleGen → CoreLoop | 事件 | `SPAWN(obstacle{lane,type})`、`FATAL_HIT`（碰撞）、`NEAR_MISS(proximity{graze\|flank})`、`PICKUP(type{lane})` |
| ObstacleGen → ComboScoring | 事件 | `NEAR_MISS(proximity)`、`PICKUP(supply/medkit)`（连击消费的接入点） |

- **关键触发点**：`NEAR_MISS` 是 P2 跨系统咬合核心——本系统发射（三轨下分 `graze`/`flank` 两类，统一按 `nearMissTier` 分层），combo-scoring 消费。`tier` 由 CoreLoop 运行时按进度切换；`laneLock` 由 CoreLoop 弯道逻辑下发，实现三轨 + 过弯约束。

## 7. 范围分层
- **MVP**：Spike + Overhead + Blocker（仅需 JUMP/SLIDE/SWITCH）+ 补给；三轨分别布置；安全轨恒在；`tier=MVP` 门控关闭 Gap/Moving/Sequence/同轨贴脸分层。相邻轨掠过近失 +1 在 MVP 引入（零成本建立贴脸心智，见 combo §7）。
- **核心**：+ Gap + Moving + Sequence（错落三轨）；启用同轨贴脸(+2) + 急救包（连击星，置于风险轨夹击位）+ 多场景（昼夜/速度分段）；`tier` 随进度升档；**CORNER 段约束生效**；二段跳窗口开放（core-loop 已确认）。
- **延展**：关卡编辑/社区路线分享、动态天气/可见度变化（注意不破坏可读性红线）。

## 8. 风险与开放问题
- **R4（已回签）**：`maxLiveObstacles=12`（可选 10）、`poolSize=24`、`spawnLookahead=1.5×屏宽`、`Vmax=13`、`pickupPoolSize=32` 已由程基岩在 Godot Web 实测回签，确认可达；三轨仅改变障碍轨分布，不改变全局 live/池上限，R4 结论不变。拾取物独立池 `pickupPoolSize=32` 不挤占障碍池。
- **近失带宽调参（CONCERN）**：`nearMissBand` 过大→贴脸无风险→潜在主导策略；过小→近失不可达。需与 combo-scoring 联调 playtest（跨 GDD 共用真值，已锁定变量名防漂移）。三轨下叠加"相邻轨横向净空"几何依赖。
- **可解性校验严密性（CONCERN，三轨新增）**：生成器必须对每个段跑"不可全堵 + 横向可达性"双重校验，否则可能产出无解/不可达段（比 2D 更易出错，因增加横向维度）。建议单测覆盖"任意 Z 至少一轨可通行"与"可达轨集合非空"。
- **车道几何常量缺口（NEW CONCERN，跨 GDD）**：`laneSpacingPx` / `playerHalfWidthPx` / `obstacleHalfWidthPx` 未在任何 GDD/架构定义；近失相邻轨判定与可解性横向净空均依赖之。需主理人路由：新增 `LaneGeometry` 常量于 `autoload/Tuning.gd`，并在 core-loop（或 LaneSystem GDD）定义"轨坐标↔世界/屏幕映射"。
- **Moving 三轨语义（CONCERN，跨 GDD）**：Moving 跨轨摆动范围与频率，需 core-loop 确认（同 combo §8）。
- **CORNER 锁定与生成耦合（CONCERN，跨 GDD）**：过弯锁定中轨由 CoreLoop/输入实现，obstacle-gen 需其下发的 `laneLock` 信号；若二者时间窗未对齐（弯前 lead 不足）会致死。需 core-loop 明确弯道窗口协议。
- **D1 视觉**：黄昏/夜晚暗调下障碍红需靠"形状+脉动"兜底（美术圣经可读性红线），夜调下实景复核（见 R5，主理人路由 art-director）。
