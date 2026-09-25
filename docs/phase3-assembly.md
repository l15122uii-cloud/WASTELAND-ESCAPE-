# Phase 3 技术搭建 · 汇编交付（主理人：游承峰）

> 项目：《WASTELAND ESCAPE / 废土逃生》（原立项名《NEON RUN / 霓虹跑酷》，已于 Phase 1→三轨重构演进）— Godot 4 · Web/HTML5 · lean
> 阶段结论：Phase 3 架构评审 **PASS**（5 CONCERNS，无 FAIL，无实现阻塞）；R4 性能预算已回签；待回填 3 项 GDD 常量后进入 Phase 4。
> ⚠️ 演进注记：架构已随三轨重构整体重写（伪透视投影三轨视角 + 平台集成），详见 `docs/architecture/architecture.md` 与各 GDD。

---

## 一、主架构（engineering-lead 程基岩）
- **渲染**：Godot 4 `gl_compatibility` / WebGL2（Web 唯一稳定路径）；2D 合批 + atlas，draw call 估算 15–30（≤50 红线 ✅）。
- **帧预算 16.67ms**：渲染 4–6 / 逻辑 2–3 / GC<0.5 / HUD 0.5 / 余量 ~6ms → 720p 稳 60fps 有余量。
- **对象池**：预实例化 24、free-list 复用、每帧零分配，消除 Web GC 抖动。
- **输入**：InputManager 统一抽象（JUMP_LOW/HIGH/SLIDE/WALL_KICK/HOLD），SwipeDetector 主指识别+去抖，MVP 仅上滑/下滑可存活（满足 P1）。
- **持久化**：SaveManager 经 JS Bridge 写 `window.localStorage`，隐私模式降级内存不阻塞。
- **视差**：ParallaxLayer motion_scale + fog/haze 卖 2.5D 纵深，零额外几何；仅 BlobShadow，无实时阴影。
- **解耦**：模块间经 EventBus 通信；HUD 不持有游戏状态，仅订阅只读快照。
- 文档：`docs/architecture/architecture.md`

## 二、ADR（4 条）
- ADR-001 引擎与渲染路径（2D/2.5D 视差，Compatibility 渲染器）
- ADR-002 性能预算/对象池/帧预算策略
- ADR-003 输入抽象层（触屏滑动+键盘）
- ADR-004 持久化方案（localStorage + 降级）
- 路径：`docs/architecture/adr/`

## 三、R4 性能预算回签（目标 60fps@720p，移动 480p 降级）
| 参数 | GDD 初值 | 回签 | 结论 |
|---|---|---|---|
| Vmax | 13 m/s | 保持 | ✅ 每帧≈10.8px 无穿隧，满 combo 14.3 仍稳 |
| maxLiveObstacles | 12 | 保持（可选 10 更稳） | ✅ 最大同屏仅 ~7–8，12 给 1.5× 余量 |
| poolSize | 24 | 保持；建议新增 pickupPoolSize=32 | ✅ |
| spawnLookahead | 1.5×屏宽 | 保持 | ✅ 覆盖≥2 间隔 |
| 首屏<5MB | — | 需定口径 | ⚠️ 已采纳推荐：游戏资源 .pck<5MB，引擎 .wasm 经 CDN 缓存另计 |
- **新增需回填 GDD 项**：① `PPM=50`（世界尺度常量，统一米/世界像素）；② `pickupPoolSize=32`；③ 首屏 5MB 口径。已派 design-strategist 回填三份 GDD。
- 文档：`docs/architecture/perf-budget.md`

## 四、架构评审 CONCERNS 与处置
- **C1 美术基调冲突**：⚠️→✅ 已解决。工程侧读到的仍是旧"霓虹黎明"；并行中 art-director 已将美术圣经修订为「黄昏/夜晚霓虹夜跑」（`design/art-bible/art-bible.md`）。
- **C2 首屏 5MB 口径**：⚠️ 已采纳推荐口径（游戏 .pck<5MB + 引擎 CDN），待用户最终确认。
- **C3 GDD 缺口（PPM、拾取池）**：已给建议回填值，已派 design-strategist 回填。
- **C4 Web 单线程**：已纳入帧预算，无阻塞。
- **C5 R5 夜调可读性**（珊瑚红 vs 危险红）：playtest 项，Phase 6 打磨阶段实景复核。

## 五、Phase 3 控制清单
`docs/architecture/control-manifest.md` 已列实现前检查项（渲染器选择、对象池、输入去抖、localStorage 降级、视差合批等）。

## 六、开放风险（跨阶段）
- **R3 商业目标/变现**：仍待用户明确（MVP 无付费，经济深度待定）。
- **R5 夜调可读性**：playtest 复核（已并入美术 R5 方案 + 工程 C5）。

## 七、下一步
1. 回填 3 项 GDD 常量（已派 design-strategist，回填中）。
2. 用户确认 C2 首屏口径（建议采纳推荐）。
3. 进入 **Phase 4 · 预制作**：并行产出 UX 规格（design-strategist）/ 资产规格（art-director）/ Epic·Story 拆分 + 测试脚手架（engineering-lead），汇编首个冲刺计划；可选做垂直切片验证核心循环。

*本汇编为 Phase 3 收口；GDD 回填与 Phase 4 推进将更新后续文档。*
