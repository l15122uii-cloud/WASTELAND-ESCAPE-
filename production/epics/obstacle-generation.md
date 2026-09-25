# Epic · ObstacleGeneration（障碍生成）

> 对应架构：architecture.md §3 ObstacleSpawner/Pool/Obstacle、§5 对象池；ADR-002。
> 真值源：`nearMissBand/Tier` 只在本 Epic 定义，ComboScoring 引用（一致性红线）。

---

### OBG-1 · ObstaclePool 对象池（poolSize=24，零分配，回收）
- 简述：预实例化 24 个障碍节点挂 ObstaclePoolRoot，初始 `visible=false`；`spawn()` 从 free-list 取节点重置，`recycle()` 越过玩家身后余量还 free-list；每帧零 `queue_free`/`instantiate`。
- GDD/ADR 溯源：obstacle-gen.md §4/§5、architecture.md §5、ADR-002、Tuning.gd（poolSize=24/maxLiveObstacles=12）。
- 验收标准（AC）：
  1. 初始化 24 节点；live 达 `maxLiveObstacles=12`（或 10）或池空 → 停止生成直至回收。
  2. 每帧零节点分配（GC 尖刺 <0.5ms，perf-budget §2）。
  3. 回收判定 = 越过玩家身后余量（非立即销毁）。
- 规模：M
- 依赖：Tuning.gd
- 切片：⭐ [MVP]

### OBG-2 · PickupPool 拾取物独立池（pickupPoolSize=32）
- 简述：补给/急救包独立对象池（不挤占障碍池）；同 free-list 激活/回收语义。
- GDD/ADR 溯源：obstacle-gen.md §4、combo-scoring.md §4、ADR-002（补 pickupPoolSize=32）、Tuning.gd。
- 验收标准（AC）：
  1. 独立池容量 32，与障碍池分离（不互相挤占 live 上限）。
  2. 拾取物经投影写屏幕坐标+scale（同障碍路径，LCS-1）。
- 规模：S
- 依赖：Tuning.gd、LCS-1
- 切片：⭐ [MVP]（切片用补给计分）

### OBG-3 · ObstacleSpawner 距离种子 RNG 调度 + z 纵深 + 门控
- 简述：按距离段派生 seed 的确定性 RNG 调度；每帧 `z-=V·dt`；按 `interval(d)`/`tier`/`inCorner` 生成；含 spawnLookahead 预读；live 上限门控。
- GDD/ADR 溯源：obstacle-gen.md §2.1/§4、architecture.md §4/§5、perf-budget §3.4。
- 验收标准（AC）：
  1. 同 `(seed,d)` 可复现（确定性 RNG，便于里程碑复核）。
  2. `interval(d)=max(intervalBase, ...·clamp(d/dFull))+jitter`；`dFull=1500` 处达 intervalMin。
  3. 首障碍在玩家前方固定安全距离生成（开局不即死，obstacle-gen.md §5）。
  4. spawnLookahead=1.5×屏宽（720p≈2.95s 预读 > reactTime）。
- 规模：L
- 依赖：OBG-1、CRL-3（供 V,d,tier）、LCS-2（lane）
- 切片：⭐（MVP 最简调度即可）

### OBG-4 · 障碍类型与碰撞（MVP：Spike/Overhead/Blocker）
- 简述：实现 MVP 三类——Spike(三角红，地面，JUMP/SWITCH)、Overhead(横杆，高处，SLIDE/SWITCH)、Blocker(满高，SWITCH only)；AABB 碰撞；类型标签。
- GDD/ADR 溯源：obstacle-gen.md §2.2/§7（MVP 类型）、architecture.md §3 Obstacle、control-manifest §C。
- 验收标准（AC）：
  1. Blocker 仅 SWITCH 可解（不可跳/滑），由三轨切轨规避（C-OBST 已 RESOLVED，无 WALL_KICK）。
  2. Spike/Overhead 各自 JUMP/SLIDE 可解（MVP 动作集）。
  3. AABB 精确碰撞；滑铲无敌帧仅对 Overhead 生效（与 LCS-5 协同）。
  4. 切片仅用 Blocker 单类（垂直切片定义）验证切轨规避核心循环。
- 规模：M
- 依赖：OBG-1、LCS-5（滑铲无敌帧）
- 切片：⭐（切片用 Blocker 单类）

### OBG-5 · 三轨可解性硬约束（不可全堵 + 横向可达性）
- 简述：对任意 Z 至少留一条可通行轨（空或仅 JUMP/SLIDE 可解）；玩家当前轨被封堵时须可横向切入某可通行轨（不穿越封堵轨）。校验失败→回退更松模式/插入中轨缺口。
- GDD/ADR 溯源：obstacle-gen.md §2.3/§8（CONCERN 可解性）、core-loop.md §2.6。
- 验收标准（AC）：
  1. 单测：随机生成 1000 段，断言「任意 Z 至少一轨可通行」与「可达轨集合非空」（test-plan 可解性用例）。
  2. `laneSwitchLead=V·laneSwitchTime(0.18)+laneBuffer(1.0)` 保证封堵轨前存在合法切入轨。
  3. 校验失败自动回退，不产出无解段（比 2D 更易错，须单测覆盖）。
- 规模：L
- 依赖：OBG-3、LCS-2（可达性递推）、CoreLoop(过弯标志)
- 切片：部分（切片用单类 Blocker 时，可解性退化为「总留两空轨」，单测轻量覆盖）

### OBG-6 · 近失检测与近失事件发射（graze/flank，碰撞优先）
- 简述：障碍越玩家判定面瞬间结算壳间最小净空 `d`；同轨擦过=`d`纵向/垂直（graze，≤tier 贴脸+2）；相邻轨掠过=`d`横向（flank，+1）；先判碰撞未撞才计近失。
- GDD/ADR 溯源：obstacle-gen.md §2.4/§4、combo-scoring.md §2.2、Tuning.gd（nearMissBand=24/nearMissTier=12）。
- 验收标准（AC）：
  1. 碰撞优先于近失：仅「未碰撞且 0<d≤band」记近失（防撞上也算近失）。
  2. 相邻轨掠过恒触发 flank +1（横向净空 60px > band 24px？→ playtest 校准，architecture §6.5 CONCERN）。
  3. 发 `NEAR_MISS(proximity{graze|flank})` 与 `PICKUP(type{lane})` 供 ComboScoring。
  4. 同帧多事件累加不丢（combo-scoring.md §5）。
- 规模：M
- 依赖：OBG-4、OBG-1、Tuning.gd
- 切片：⭐（切片用 flank +1 建立贴脸心智）

### OBG-7 · 过弯段中轨约束（仅中轨 JUMP/SLIDE 可解）
- 简述：CORNER 段 `laneLock=center` 时仅中轨生成 Spike/Overhead（核心档可 Gap），绝不生成 Blocker/Moving/Sequence 跨轨；弯前预留 ≥ laneSwitchLead 让玩家切回中轨。
- GDD/ADR 溯源：obstacle-gen.md §2.5、core-loop.md §2.6、architecture.md §6.3。
- 验收标准（AC）：
  1. `inCorner=true` 区间仅中轨生成且为 JUMP/SLIDE 可解类型（无 SWITCH-only）。
  2. 弯前最后可解窗口不封堵中轨；CORNER 段无「锁中轨却堵死中轨」致死漏洞（obstacle-gen.md §5）。
  3. 与 CoreLoop 弯道窗口协议对齐（laneLock 信号时序，C-D2/跨 GDD CONCERN）。
- 规模：M
- 依赖：OBG-3、LCS-6（CORNER 触发）
- 切片：⭐（切片过弯锁中轨需此约束，最简用中轨 Spike/Overhead）

### OBG-8 · 核心档障碍类型（Gap/Moving/Sequence）+ 二段跳窗口
- 简述：核心档启用 Gap(跳时机)/Moving(跨轨摆动)/Sequence(错落三轨)；Gap 宽度按 V 与二段跳可达距离约束保证可达。
- GDD/ADR 溯源：obstacle-gen.md §2.2/§2.6/§7（CORE）、combo-scoring.md §7。
- 验收标准（AC）：
  1. Gap 按当前 `V` 与二段跳可达距离约束保证可达（core-loop §2.6 已确认）。
  2. Moving 跨轨摆动范围/频率与 CoreLoop 对齐（obstacle-gen §8 CONCERN，待协同）。
  3. Sequence 错落三轨强制连续切轨，漏切=撞=死（P2 风险即奖励）。
- 规模：L
- 依赖：OBG-4、LCS-5（二段跳）、CoreLoop(过弯/二段跳门控)
- 切片：不在切片内（CORE/延展档）
